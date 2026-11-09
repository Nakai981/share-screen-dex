import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/workspace.dart';
import 'browser/browser_window.dart';
import 'desktop.dart';
import 'keyboard_preferences.dart';
import 'theme.dart';
import 'cute_cursor.dart';

/// The iPhone keeps keyboard focus. Its mouse/AssistiveTouch events are mapped
/// onto the external workspace rather than relying on an interactive scene.
class HardwareControllerPage extends StatefulWidget {
  const HardwareControllerPage({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  State<HardwareControllerPage> createState() => _HardwareControllerPageState();
}

class _HardwareControllerPageState extends State<HardwareControllerPage> {
  late final notes = SyncedTextController(text: widget.workspace.notes);
  final pageText = TextEditingController();
  final remoteFocus = FocusNode();
  final notesFocus = FocusNode();
  final addressFocus = FocusNode();
  final pageFocus = FocusNode();
  late DeskApp? active;
  late KeyboardLanguage language;
  WorkspaceController get workspace => widget.workspace;

  @override
  void initState() {
    super.initState();
    active = workspace.activeApp;
    language = workspace.keyboardLanguage;
    workspace.addListener(_sync);
  }

  void _sync() {
    notes.syncRemote(workspace.notes);
    if (active != workspace.activeApp ||
        language != workspace.keyboardLanguage) {
      setState(() {
        active = workspace.activeApp;
        language = workspace.keyboardLanguage;
      });
    }
  }

  void _open(DeskApp app) =>
      workspace.dispatch({'type': 'open', 'app': app.name});
  void _windowAction(String action) {
    if (workspace.activeApp case final app?) {
      workspace.dispatch({'type': action, 'app': app.name});
    }
  }

  void _address() {
    _open(DeskApp.browser);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) addressFocus.requestFocus();
    });
  }

  void _selected() {
    if (workspace.activeApp == DeskApp.notes) notesFocus.requestFocus();
  }

  void _sendPage() {
    workspace.dispatch({'type': 'browserText', 'text': pageText.text});
    pageText.clear();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (notesFocus.hasFocus || addressFocus.hasFocus || pageFocus.hasFocus) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => const Offset(-16, 0),
      LogicalKeyboardKey.arrowRight => const Offset(16, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -16),
      LogicalKeyboardKey.arrowDown => const Offset(0, 16),
      _ => null,
    };
    if (delta != null) {
      workspace.dispatch({
        'type': 'pointerMove',
        'dx': delta.dx,
        'dy': delta.dy,
      });
      return KeyEventResult.handled;
    }
    if ([
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ].contains(event.logicalKey)) {
      workspace.dispatch({'type': 'click'});
      _selected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    workspace.dispatch({'type': 'pointerUp'});
    workspace.removeListener(_sync);
    for (final node in [remoteFocus, notesFocus, addressFocus, pageFocus]) {
      node.dispose();
    }
    notes.dispose();
    pageText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      for (final meta in [false, true]) ...{
        SingleActivator(
          LogicalKeyboardKey.digit1,
          control: !meta,
          meta: meta,
        ): () =>
            _open(DeskApp.notes),
        SingleActivator(
          LogicalKeyboardKey.digit2,
          control: !meta,
          meta: meta,
        ): () =>
            _open(DeskApp.browser),
        SingleActivator(
          LogicalKeyboardKey.digit3,
          control: !meta,
          meta: meta,
        ): () =>
            _open(DeskApp.guide),
        SingleActivator(
          LogicalKeyboardKey.keyW,
          control: !meta,
          meta: meta,
        ): () =>
            _windowAction('close'),
        SingleActivator(
          LogicalKeyboardKey.keyM,
          control: !meta,
          meta: meta,
        ): () =>
            _windowAction('minimize'),
        SingleActivator(LogicalKeyboardKey.keyL, control: !meta, meta: meta):
            _address,
        SingleActivator(
          LogicalKeyboardKey.keyT,
          shift: true,
          control: !meta,
          meta: meta,
        ): () =>
            workspace.dispatch({'type': 'arrange'}),
      },
      const SingleActivator(LogicalKeyboardKey.tab, alt: true): () =>
          workspace.dispatch({'type': 'cycleWindow'}),
    },
    child: Focus(
      focusNode: remoteFocus,
      autofocus: true,
      onKeyEvent: _key,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chuột & bàn phím', style: TextStyle(fontSize: 17)),
          actions: [
            IconButton(
              tooltip: 'Sắp xếp cửa sổ',
              onPressed: () => workspace.dispatch({'type': 'arrange'}),
              icon: const Icon(Icons.view_column_outlined),
            ),
            IconButton(
              tooltip: 'Khôi phục taskbar',
              onPressed: () => workspace.dispatch({'type': 'recoverDesktop'}),
              icon: const Icon(Icons.restore_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Điều khiển desktop ngoài',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Trên iPhone: bật Cài đặt → Trợ năng → Cảm ứng → AssistiveTouch, rồi kết nối chuột trong Thiết bị. Di chuyển/bấm trong vùng bên dưới để điều khiển màn hình ngoài.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: workspace,
                  builder: (context, _) => AspectRatio(
                    aspectRatio: workspace.canvasSize.aspectRatio,
                    child: RemotePointerSurface(
                      workspace: workspace,
                      onSelect: _selected,
                      onBegin: remoteFocus.requestFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sơ đồ cửa sổ · Bấm để chọn, kéo thanh tiêu đề để di chuyển. Với AssistiveTouch, bấm/giữ-kéo trên vùng này; iOS có thể không gửi chuyển động hover cho ứng dụng.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                if (active == DeskApp.notes)
                  TextField(
                    key: const ValueKey('hardware-notes'),
                    controller: notes,
                    focusNode: notesFocus,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 50000,
                    keyboardType: TextInputType.multiline,
                    hintLocales: language.hintLocales,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Gõ vào Ghi chú bằng bàn phím Bluetooth',
                      counterText: '',
                    ),
                    onChanged: (value) =>
                        workspace.dispatch({'type': 'notes', 'text': value}),
                  ),
                if (active == DeskApp.browser) ...[
                  BrowserAddressField(
                    workspace: workspace,
                    id: 'hardware',
                    focusNode: addressFocus,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('hardware-page-input'),
                    controller: pageText,
                    focusNode: pageFocus,
                    hintLocales: language.hintLocales,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      labelText: 'Chữ gửi vào ô đã chọn trên trang',
                      suffixIcon: IconButton(
                        tooltip: 'Gửi vào trang',
                        onPressed: _sendPage,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ),
                    onSubmitted: (_) => _sendPage(),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Ctrl/⌘ + 1, 2, 3: mở ứng dụng · Ctrl/⌘ + L: địa chỉ · Ctrl/⌘ + W: đóng · Ctrl/⌘ + M: thu nhỏ · Ctrl/⌘ + Shift + T: xếp cạnh nhau · Alt + Tab: đổi cửa sổ.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RemotePointerSurface extends StatefulWidget {
  const RemotePointerSurface({
    super.key,
    required this.workspace,
    this.onSelect,
    this.onBegin,
  });
  final WorkspaceController workspace;
  final VoidCallback? onSelect;
  final VoidCallback? onBegin;
  @override
  State<RemotePointerSurface> createState() => _RemotePointerSurfaceState();
}

class _RemotePointerSurfaceState extends State<RemotePointerSurface> {
  Offset? down;
  int? pointer;
  bool moved = false;
  void _position(Offset local, Size size) {
    final next = Offset(
      local.dx / size.width * widget.workspace.canvasSize.width,
      local.dy / size.height * 900,
    );
    widget.workspace.dispatch({
      'type': 'pointerMove',
      'dx': next.dx - widget.workspace.cursor.dx,
      'dy': next.dy - widget.workspace.cursor.dy,
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MouseRegion(
      cursor: SystemMouseCursors.precise,
      child: Listener(
        key: const ValueKey('hardware-pointer-surface'),
        behavior: HitTestBehavior.opaque,
        onPointerHover: (event) =>
            _position(event.localPosition, constraints.biggest),
        onPointerDown: (event) {
          if (pointer != null || event.buttons & kPrimaryButton == 0) return;
          widget.onBegin?.call();
          pointer = event.pointer;
          down = event.localPosition;
          moved = false;
          _position(event.localPosition, constraints.biggest);
          widget.workspace.dispatch({'type': 'pointerDown'});
        },
        onPointerMove: (event) {
          if (event.pointer != pointer) return;
          if ((event.localPosition - down!).distance > 5) moved = true;
          _position(event.localPosition, constraints.biggest);
        },
        onPointerUp: (event) {
          if (event.pointer != pointer) return;
          widget.workspace.dispatch({'type': 'pointerUp'});
          if (!moved) {
            widget.workspace.dispatch({'type': 'click'});
            widget.onSelect?.call();
          }
          pointer = null;
          down = null;
        },
        onPointerCancel: (_) {
          widget.workspace.dispatch({'type': 'pointerUp'});
          pointer = null;
          down = null;
        },
        onPointerSignal: (event) {
          if (event is PointerScrollEvent &&
              widget.workspace.activeApp == DeskApp.browser) {
            GestureBinding.instance.pointerSignalResolver.register(
              event,
              (_) => widget.workspace.dispatch({
                'type': 'browserScroll',
                'dy': event.scrollDelta.dy,
              }),
            );
          }
        },
        child: ListenableBuilder(
          listenable: widget.workspace,
          builder: (context, _) => CustomPaint(
            painter: _RemoteDesktopPainter(widget.workspace),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _RemoteDesktopPainter extends CustomPainter {
  _RemoteDesktopPainter(this.workspace);
  final WorkspaceController workspace;
  @override
  void paint(Canvas canvas, Size size) {
    final logical = workspace.canvasSize;
    canvas.save();
    canvas.scale(size.width / logical.width, size.height / logical.height);
    WallpaperPainter(workspace.wallpaper).paint(canvas, logical);
    for (final w in workspace.windows.where((w) => !w.minimized)) {
      final r = w.visibleRect;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(14)),
        Paint()
          ..color = w.app == workspace.activeApp
              ? Colors.white
              : const Color(0xFFC5D7DD),
      );
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, r.width, 48),
        Paint()..color = const Color(0xFFE3EBEF),
      );
      final text = TextPainter(
        text: TextSpan(
          text: switch (w.app) {
            DeskApp.notes => 'Ghi chú',
            DeskApp.browser => 'Trình duyệt',
            DeskApp.guide => 'Bắt đầu',
          },
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(1, r.width - 150));
      text.paint(canvas, r.topLeft + const Offset(16, 10));
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(r.right - 23 - 46 * i, r.top + 24),
          7,
          Paint()..color = i == 0 ? const Color(0xFFE87871) : AppColors.muted,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(workspace.dockRect, const Radius.circular(20)),
      Paint()..color = const Color(0xFFF5F8F9),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        workspace.dockItem(i).center,
        21,
        Paint()
          ..color = [
            AppColors.blue,
            const Color(0xFF378A8E),
            const Color(0xFF358677),
            const Color(0xFFB57960),
          ][i],
      );
    }
    canvas.save();
    canvas.translate(workspace.cursor.dx, workspace.cursor.dy);
    const CuteCursorPainter().paint(
      canvas,
      cuteCursorSize * workspace.cursorScale,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RemoteDesktopPainter oldDelegate) => true;
}
