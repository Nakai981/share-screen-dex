import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../domain/workspace.dart';
import 'desktop_motion.dart';

/// Keeps the outgoing content alive until its close/minimize animation ends.
/// This state belongs to each renderer, never to the shared session clock.
class DesktopWindowMotion extends StatefulWidget {
  const DesktopWindowMotion({
    super.key,
    required this.app,
    required this.window,
    required this.builder,
    this.canvasSize = desktopSize,
    this.layoutEpoch = 0,
    this.dockOrigin,
    this.occluded = false,
    this.occlusionRect,
  });
  final DeskApp app;
  final DeskWindow? window;
  final Widget Function(DeskWindow window) builder;
  final Size canvasSize;
  final int layoutEpoch;
  final Offset? dockOrigin;
  final bool occluded;
  final Rect? occlusionRect;
  @override
  State<DesktopWindowMotion> createState() => _DesktopWindowMotionState();
}

class _DesktopWindowMotionState extends State<DesktopWindowMotion>
    with TickerProviderStateMixin {
  late final AnimationController visibility = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final AnimationController geometry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  DeskWindow? retained;
  RectTween? geometryTween;
  bool shown = false;
  bool dockTransition = true;
  bool reduced = false;
  bool initialized = false;
  int lastLayoutEpoch = 0;

  DeskWindow _copy(DeskWindow w) => DeskWindow(
    app: w.app,
    rect: w.rect,
    minimized: w.minimized,
    maximized: w.maximized,
    canvasWidth: w.canvasWidth,
    workBottom: w.workBottom,
  );
  Rect get currentRect =>
      geometryTween?.transform(geometry.value) ??
      retained?.visibleRect ??
      Rect.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (!initialized) {
      initialized = true;
      _update();
    }
    if (reduced) {
      visibility.value = shown ? 1 : 0;
      geometry.value = 1;
    }
  }

  @override
  void didUpdateWidget(DesktopWindowMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    final next = widget.window;
    final wasMinimized = retained?.minimized == true;
    final nextShown = next != null && !next.minimized;
    if (next != null) {
      final before = currentRect;
      final maximizeChanged =
          retained != null && retained!.maximized != next.maximized;
      retained = _copy(next);
      if ((maximizeChanged || lastLayoutEpoch != widget.layoutEpoch) &&
          before != next.visibleRect &&
          shown &&
          nextShown &&
          !reduced) {
        geometryTween = RectTween(begin: before, end: next.visibleRect);
        geometry.value = 0;
        geometry.animateWith(
          SpringSimulation(DesktopMotion.layout, 0, 1, 0, snapToEnd: true),
        );
      } else if (geometryTween?.end != next.visibleRect) {
        geometryTween = RectTween(
          begin: next.visibleRect,
          end: next.visibleRect,
        );
        geometry.value = 1;
      }
    }
    lastLayoutEpoch = widget.layoutEpoch;
    if (nextShown != shown) {
      // Fresh apps enter close to their final size. Restore/minimize uses the
      // classic dock scale trajectory; a close fades in place.
      dockTransition = nextShown ? wasMinimized : next?.minimized == true;
      shown = nextShown;
      if (reduced) {
        visibility.value = shown ? 1 : 0;
      } else if (shown) {
        visibility.animateWith(
          SpringSimulation(
            DesktopMotion.opening,
            visibility.value,
            1,
            visibility.velocity,
            snapToEnd: true,
          ),
        );
      } else {
        visibility.animateBackWith(
          SpringSimulation(
            DesktopMotion.closing,
            visibility.value,
            0,
            visibility.velocity,
            snapToEnd: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    visibility.dispose();
    geometry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([visibility, geometry]),
    // The contents are built once per workspace update, not on animation ticks.
    child: retained == null
        ? null
        : RepaintBoundary(child: widget.builder(retained!)),
    builder: (context, content) {
      if (retained == null ||
          (visibility.isDismissed && !shown && widget.window == null)) {
        return const SizedBox.shrink();
      }
      final progress = visibility.value.clamp(0.0, 1.0);
      final rect = currentRect;
      final target = retained!.visibleRect;
      final origin =
          widget.dockOrigin ??
          dockItemRect(dockIndex(widget.app), widget.canvasSize).center;
      final offset = dockTransition
          ? (origin - rect.center) * (1 - progress)
          : Offset(0, 16 * (1 - progress));
      final scale = dockTransition
          ? .16 + .84 * progress
          : .94 + .06 * progress;
      return Positioned.fromRect(
        rect: target,
        child: ClipPath(
          key: ValueKey('window-clip-${widget.app.name}'),
          clipBehavior: widget.occlusionRect == null
              ? Clip.none
              : Clip.hardEdge,
          clipper: widget.occlusionRect == null
              ? null
              : _WindowOcclusionClipper(
                  widget.occlusionRect!.shift(-target.topLeft),
                ),
          child: Offstage(
            offstage: widget.occluded || (visibility.isDismissed && !shown),
            child: IgnorePointer(
              ignoring: !shown || progress < .95,
              child: ExcludeSemantics(
                excluding: !shown,
                child: Transform.translate(
                  offset: offset + rect.topLeft - target.topLeft,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.diagonal3Values(
                      rect.width / target.width,
                      rect.height / target.height,
                      1,
                    ),
                    child: Transform.scale(
                      key: ValueKey('window-scale-${widget.app.name}'),
                      scale: scale,
                      child: Opacity(
                        key: ValueKey('window-opacity-${widget.app.name}'),
                        opacity: progress.clamp(0, 1),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _WindowOcclusionClipper extends CustomClipper<Path> {
  _WindowOcclusionClipper(this.cover);
  final Rect cover;
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect((Offset.zero & size).inflate(64)),
    Path()..addRect(cover),
  );
  @override
  bool shouldReclip(_WindowOcclusionClipper oldClipper) =>
      cover != oldClipper.cover;
}
