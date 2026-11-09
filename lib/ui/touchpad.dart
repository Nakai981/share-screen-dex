import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../domain/workspace.dart';
import 'theme.dart';

class Touchpad extends StatefulWidget {
  const Touchpad({
    super.key,
    required this.workspace,
    required this.dragging,
    required this.sensitivity,
    this.height = 222,
    this.onSelect,
  });
  final WorkspaceController workspace;
  final bool dragging;
  final double sensitivity;
  final double? height;
  final VoidCallback? onSelect;
  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad> {
  bool touching = false;
  Offset _lastLongPosition = Offset.zero;
  Offset? _hoverPosition;
  Offset? _mouseDown;
  int? _mousePointer;
  bool _mouseMoved = false;
  void _select() {
    widget.workspace.dispatch({'type': 'click'});
    widget.onSelect?.call();
  }

  void _move(Offset delta) => widget.workspace.dispatch({
    'type': 'pointerMove',
    'dx': delta.dx * 3.5 * widget.sensitivity,
    'dy': delta.dy * 3.5 * widget.sensitivity,
  });
  void _release() {
    widget.workspace.dispatch({'type': 'pointerUp'});
    if (mounted) setState(() => touching = false);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bàn di chuột. Vuốt để di con trỏ, chạm để chọn, giữ để kéo.',
    child: MouseRegion(
      cursor: SystemMouseCursors.none,
      onEnter: (event) => _hoverPosition = event.localPosition,
      onExit: (_) => _hoverPosition = null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerHover: (event) {
          if (_hoverPosition case final previous?) {
            _move(event.localPosition - previous);
          }
          _hoverPosition = event.localPosition;
        },
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse ||
              event.buttons & kPrimaryButton == 0) {
            return;
          }
          _mousePointer = event.pointer;
          _mouseDown = event.localPosition;
          _mouseMoved = false;
          widget.workspace.dispatch({'type': 'pointerDown'});
        },
        onPointerMove: (event) {
          if (event.pointer != _mousePointer) return;
          _mouseMoved =
              _mouseMoved || (event.localPosition - _mouseDown!).distance > 4;
          _move(event.delta);
          _hoverPosition = event.localPosition;
        },
        onPointerUp: (event) {
          if (event.pointer != _mousePointer) return;
          widget.workspace.dispatch({'type': 'pointerUp'});
          if (!_mouseMoved) _select();
          _mousePointer = null;
        },
        onPointerCancel: (event) {
          if (event.pointer != _mousePointer) return;
          _mousePointer = null;
          widget.workspace.dispatch({'type': 'pointerUp'});
        },
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            GestureBinding.instance.pointerSignalResolver.register(
              event,
              (_) => widget.workspace.dispatch({
                'type': 'browserScroll',
                'dy': event.scrollDelta.dy,
              }),
            );
          }
        },
        child: GestureDetector(
          supportedDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
            PointerDeviceKind.trackpad,
          },
          key: const ValueKey('touchpad'),
          behavior: HitTestBehavior.opaque,
          onTap: _select,
          onPanStart: (_) {
            setState(() => touching = true);
            if (widget.dragging) {
              widget.workspace.dispatch({'type': 'pointerDown'});
            }
          },
          onPanUpdate: (details) => _move(details.delta),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          onLongPressStart: (details) {
            setState(() => touching = true);
            _lastLongPosition = details.localPosition;
            widget.workspace.dispatch({'type': 'pointerDown'});
          },
          onLongPressMoveUpdate: (details) {
            _move(details.localPosition - _lastLongPosition);
            _lastLongPosition = details.localPosition;
          },
          onLongPressEnd: (_) => _release(),
          onLongPressCancel: _release,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 130),
            height: widget.height,
            decoration: BoxDecoration(
              color: touching
                  ? const Color(0xFFE7EEF8)
                  : const Color(0xFFECF0F4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: touching
                    ? AppColors.blue.withValues(alpha: .45)
                    : const Color(0xFFDCE3EA),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                painter: const _TouchpadDots(),
                child: Stack(
                  children: [
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.dragging
                                  ? Icons.open_with_rounded
                                  : Icons.touch_app_outlined,
                              size: 30,
                              color: touching
                                  ? AppColors.blue
                                  : const Color(0xFF9BAAB8),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.dragging
                                  ? 'Kéo từ thanh tiêu đề cửa sổ'
                                  : 'Rê chuột hoặc vuốt để điều khiển',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Text(
                        'Giữ rồi vuốt để kéo',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: Color(0xFF9BAAB8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TouchpadDots extends CustomPainter {
  const _TouchpadDots();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFC8D2DC);
    for (double x = 12; x < size.width; x += 16) {
      for (double y = 12; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), .65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TouchpadDots oldDelegate) => false;
}
