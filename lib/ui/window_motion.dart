import 'package:flutter/material.dart';

import '../domain/workspace.dart';

/// Keeps the outgoing content alive until its close/minimize animation ends.
/// This state belongs to each renderer, never to the shared session clock.
class DesktopWindowMotion extends StatefulWidget {
  const DesktopWindowMotion({
    super.key,
    required this.app,
    required this.window,
    required this.builder,
    this.canvasSize = desktopSize,
  });
  final DeskApp app;
  final DeskWindow? window;
  final Widget Function(DeskWindow window) builder;
  final Size canvasSize;
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

  DeskWindow _copy(DeskWindow w) => DeskWindow(
    app: w.app,
    rect: w.rect,
    minimized: w.minimized,
    maximized: w.maximized,
    canvasWidth: w.canvasWidth,
  );
  Rect get currentRect =>
      geometryTween?.transform(Curves.easeOutCubic.transform(geometry.value)) ??
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
    final nextShown = next != null && !next.minimized;
    if (next != null) {
      final before = currentRect;
      final maximizeChanged =
          retained != null && retained!.maximized != next.maximized;
      retained = _copy(next);
      if (maximizeChanged && shown && nextShown && !reduced) {
        geometryTween = RectTween(begin: before, end: next.visibleRect);
        geometry.forward(from: 0);
      } else if (geometryTween?.end != next.visibleRect) {
        geometryTween = RectTween(
          begin: next.visibleRect,
          end: next.visibleRect,
        );
        geometry.value = 1;
      }
    }
    if (nextShown != shown) {
      dockTransition = nextShown || next?.minimized == true;
      shown = nextShown;
      if (reduced) {
        visibility.value = shown ? 1 : 0;
      } else if (shown) {
        visibility.forward();
      } else {
        visibility.reverse();
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
      final progress = Curves.easeOutCubic.transform(visibility.value);
      final rect = currentRect;
      final target = retained!.visibleRect;
      final origin = dockItemRect(
        dockIndex(widget.app),
        widget.canvasSize,
      ).center;
      final offset = dockTransition
          ? (origin - rect.center) * (1 - progress)
          : Offset(0, 16 * (1 - progress));
      final scale = dockTransition
          ? .16 + .84 * progress
          : .94 + .06 * progress;
      return Positioned.fromRect(
        rect: target,
        child: Offstage(
          offstage: visibility.isDismissed && !shown,
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
      );
    },
  );
}
