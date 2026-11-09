import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../domain/workspace.dart';
import '../platform/external_browser_attachment.dart';
import 'theme.dart';
import 'desktop_dock.dart';
import 'window_motion.dart';
import 'browser/browser_window.dart';
import 'keyboard_preferences.dart';
import 'desktop_viewport.dart';
import 'fullscreen.dart';
import 'cute_cursor.dart';

class DesktopView extends StatelessWidget {
  const DesktopView({
    super.key,
    required this.workspace,
    this.interactive = true,
    this.showChrome = true,
  });
  final WorkspaceController workspace;
  final bool interactive;
  final bool showChrome;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workspace.sceneChanges,
    builder: (context, _) => ColoredBox(
      color: wallpaperColors[workspace.wallpaper].$1,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: workspace.canvasSize.width,
            height: workspace.canvasSize.height,
            child: IgnorePointer(
              ignoring: !interactive,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 450),
                          child: CustomPaint(
                            key: ValueKey(workspace.wallpaper),
                            painter: WallpaperPainter(workspace.wallpaper),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 92,
                      bottom: 140,
                      child: _WallpaperSignature(),
                    ),
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: desktopTop,
                      child: _DesktopBar(),
                    ),
                    for (final app in [
                      ...DeskApp.values.where(
                        (app) => !workspace.windows.any((w) => w.app == app),
                      ),
                      ...workspace.windows.map((w) => w.app),
                    ])
                      DesktopWindowMotion(
                        key: ValueKey('window-motion-${app.name}'),
                        app: app,
                        animate:
                            app != DeskApp.browser ||
                            !usesExternalBrowserHost(
                              external: workspace.forwardAction != null,
                            ),
                        occluded: workspace.isWindowOccluded(app),
                        occlusionRect:
                            workspace.activeApp == DeskApp.browser &&
                                app != DeskApp.browser
                            ? workspace.windows
                                  .lastWhere((w) => !w.minimized)
                                  .visibleRect
                            : null,
                        canvasSize: workspace.canvasSize,
                        layoutEpoch: workspace.layoutEpoch,
                        dockOrigin: workspace.dockItem(dockIndex(app)).center,
                        window: workspace.windows
                            .where((w) => w.app == app)
                            .firstOrNull,
                        builder: (window) => PointerInterceptor(
                          intercepting:
                              (kIsWeb || workspace.forwardAction == null) &&
                              window.app != DeskApp.browser &&
                              workspace.activeApp == window.app,
                          child: _DesktopWindow(
                            window: window,
                            workspace: workspace,
                            interactive: interactive,
                          ),
                        ),
                      ),
                    if (showChrome)
                      Positioned.fromRect(
                        rect: workspace.dockRect,
                        child: PointerInterceptor(
                          intercepting:
                              kIsWeb || workspace.forwardAction == null,
                          child: ListenableBuilder(
                            listenable: workspace.pointerChanges,
                            builder: (context, _) =>
                                DesktopDock(workspace: workspace),
                          ),
                        ),
                      ),
                    if (showChrome)
                      ListenableBuilder(
                        listenable: workspace.pointerChanges,
                        builder: (context, _) => Positioned(
                          key: const ValueKey('desktop-cursor'),
                          left: workspace.cursor.dx,
                          top: workspace.cursor.dy,
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: cuteCursorSize * workspace.cursorScale,
                                painter: const CuteCursorPainter(),
                              ),
                            ),
                          ),
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

const wallpaperColors = [
  (Color(0xFF173A46), Color(0xFF45877F), Color(0xFFA6D4CA)),
  (Color(0xFF293A67), Color(0xFF637AB0), Color(0xFFB5C7EB)),
  (Color(0xFF503F46), Color(0xFFA47875), Color(0xFFE9BBA2)),
];

class WallpaperPainter extends CustomPainter {
  const WallpaperPainter(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final colors = wallpaperColors[index];
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.$1);
    final scaleX = size.width / 1440;
    final scaleY = size.height / 900;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    // An oversized, folded ribbon makes the workspace recognizable without
    // images or network requests. It remains crisp on a physical 4K display.
    final fold = Path()
      ..moveTo(860, -150)
      ..cubicTo(1320, 120, 980, 260, 1160, 530)
      ..cubicTo(1280, 710, 1510, 620, 1620, 1020)
      ..lineTo(940, 1020)
      ..cubicTo(1160, 650, 690, 590, 720, 320)
      ..cubicTo(730, 100, 1110, 80, 860, -150)
      ..close();
    canvas.drawPath(fold, Paint()..color = colors.$2);
    final edge = Path()
      ..moveTo(1120, -80)
      ..cubicTo(1560, 210, 1120, 350, 1350, 600)
      ..cubicTo(1460, 710, 1560, 760, 1600, 1000)
      ..lineTo(1420, 1000)
      ..cubicTo(1390, 790, 1270, 710, 1210, 600)
      ..cubicTo(1000, 260, 1430, 210, 1010, -80)
      ..close();
    canvas.drawPath(edge, Paint()..color = colors.$3.withValues(alpha: .65));
    canvas.restore();
  }

  @override
  bool shouldRepaint(WallpaperPainter oldDelegate) =>
      oldDelegate.index != index;
}

class _WallpaperSignature extends StatelessWidget {
  const _WallpaperSignature();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Thêm không gian.\nThêm khả năng.',
        style: TextStyle(
          fontSize: 42,
          height: 1.15,
          letterSpacing: -1.7,
          color: Color(0x66FFFFFF),
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: 16),
      Text(
        'Một chiếc điện thoại. Một góc làm việc mới.',
        style: TextStyle(color: Color(0x88FFFFFF), fontSize: 14),
      ),
    ],
  );
}

class _DesktopBar extends StatelessWidget {
  const _DesktopBar();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    color: const Color(0x66122831),
    child: const Row(
      children: [
        Icon(Icons.space_dashboard_rounded, color: Colors.white, size: 16),
        SizedBox(width: 10),
        Text(
          'SideScreen',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        SizedBox(width: 32),
        Expanded(
          child: Text(
            'Không gian cá nhân',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 12),
          ),
        ),
        Icon(Icons.phonelink_ring_rounded, color: Color(0xBFFFFFFF), size: 16),
        SizedBox(width: 8),
        Text(
          'Điều khiển từ điện thoại',
          style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 12),
        ),
      ],
    ),
  );
}

class _DesktopWindow extends StatelessWidget {
  const _DesktopWindow({
    required this.window,
    required this.workspace,
    this.interactive = true,
  });
  final DeskWindow window;
  final WorkspaceController workspace;
  final bool interactive;
  void action(String type, [Offset delta = Offset.zero]) => workspace.dispatch({
    'type': type,
    'app': window.app.name,
    'dx': delta.dx,
    'dy': delta.dy,
  });
  @override
  Widget build(BuildContext context) {
    final notes = window.app == DeskApp.notes;
    final active = workspace.activeApp == window.app;
    return Listener(
      onPointerDown: (_) => action('focus'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFFDBE6EC) : const Color(0x88D4DFE5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: active ? .22 : .12),
              blurRadius: 28,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Column(
                children: [
                  PointerInterceptor(
                    intercepting:
                        active && (kIsWeb || workspace.forwardAction == null),
                    child: Container(
                      height: windowTitleHeight,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7F9FA),
                        border: Border(
                          bottom: BorderSide(color: AppColors.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) => action('moveWindow', d.delta),
                              onDoubleTap: () => action('maximize'),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Icon(
                                    switch (window.app) {
                                      DeskApp.notes => Icons.edit_note_rounded,
                                      DeskApp.guide =>
                                        Icons.auto_awesome_rounded,
                                      DeskApp.browser => Icons.public_rounded,
                                    },
                                    color: notes
                                        ? AppColors.blue
                                        : const Color(0xFF358677),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      switch (window.app) {
                                        DeskApp.notes => 'Ghi chú',
                                        DeskApp.guide =>
                                          'Bắt đầu cùng SideScreen',
                                        DeskApp.browser => 'Trình duyệt',
                                      },
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _WindowButton(
                            label: 'Thu nhỏ',
                            icon: Icons.remove_rounded,
                            onTap: () => action('minimize'),
                          ),
                          _WindowButton(
                            label: window.maximized ? 'Khôi phục' : 'Phóng to',
                            icon: window.maximized
                                ? Icons.filter_none_rounded
                                : Icons.crop_square_rounded,
                            onTap: () => action('maximize'),
                          ),
                          _WindowButton(
                            label: 'Đóng',
                            icon: Icons.close_rounded,
                            onTap: () => action('close'),
                            close: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: switch (window.app) {
                      DeskApp.notes => _NotesContent(workspace: workspace),
                      DeskApp.guide => const _GuideContent(),
                      DeskApp.browser => BrowserWindow(
                        workspace: workspace,
                        windowWidth: window.visibleRect.width,
                        interactive: interactive,
                      ),
                    },
                  ),
                ],
              ),
              if (!window.maximized)
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 28,
                  height: 28,
                  child: PointerInterceptor(
                    intercepting:
                        active && (kIsWeb || workspace.forwardAction == null),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => action('resizeWindow', d.delta),
                        child: const Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.south_east_rounded,
                              size: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.close = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool close;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: windowControlWidth,
    height: windowTitleHeight,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        hoverColor: close ? const Color(0xFFFFE5DF) : AppColors.line,
        child: Icon(
          icon,
          size: 16,
          color: close ? const Color(0xFFC44D44) : AppColors.muted,
        ),
      ),
    ),
  );
}

class _GuideContent extends StatelessWidget {
  const _GuideContent();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F1EC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.waving_hand_outlined,
            color: Color(0xFF358677),
            size: 27,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Chào không gian mới.',
          style: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Đặt điện thoại xuống. Mở rộng điều bạn có thể làm.',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 28),
        const _GuideRow(
          icon: Icons.touch_app_outlined,
          title: 'Di chuyển thật tự nhiên',
          subtitle: 'Vuốt touchpad để di chuột, chạm để chọn.',
        ),
        const SizedBox(height: 20),
        const _GuideRow(
          icon: Icons.open_with_rounded,
          title: 'Sắp xếp theo cách của bạn',
          subtitle: 'Bật Kéo cửa sổ, rồi kéo từ thanh tiêu đề.',
        ),
        const SizedBox(height: 20),
        const _GuideRow(
          icon: Icons.keyboard_rounded,
          title: 'Viết ngay từ điện thoại',
          subtitle: 'Chọn Bàn phím để nhập nội dung vào Ghi chú.',
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Góc cửa sổ để đổi kích thước. Thanh tác vụ để mở lại ứng dụng.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 23, color: const Color(0xFF358677)),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _NotesContent extends StatefulWidget {
  const _NotesContent({required this.workspace});
  final WorkspaceController workspace;
  @override
  State<_NotesContent> createState() => _NotesContentState();
}

class _NotesContentState extends State<_NotesContent> {
  late final SyncedTextController text = SyncedTextController(
    text: widget.workspace.notes,
  );
  @override
  void didUpdateWidget(_NotesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    text.syncRemote(widget.workspace.notes);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 14),
        child: Row(
          children: [
            const Text(
              'Một ý tưởng mới',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w600,
                letterSpacing: -.7,
              ),
            ),
            const Spacer(),
            Tooltip(
              message: 'Nội dung được giữ trên điện thoại',
              child: Icon(
                Icons.phone_iphone_rounded,
                size: 17,
                color: AppColors.muted.withValues(alpha: .7),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: TextField(
          key: const ValueKey('desktop-notes'),
          controller: text,
          readOnly: widget.workspace.forwardAction != null,
          canRequestFocus: widget.workspace.forwardAction == null,
          showCursor: widget.workspace.forwardAction == null,
          enableInteractiveSelection: widget.workspace.forwardAction == null,
          expands: true,
          maxLines: null,
          minLines: null,
          maxLength: 50000,
          keyboardType: TextInputType.multiline,
          hintLocales: widget.workspace.keyboardLanguage.hintLocales,
          autocorrect: true,
          enableSuggestions: true,
          textCapitalization: TextCapitalization.sentences,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(
            fontSize: 16,
            height: 1.9,
            color: Color(0xFF4C606A),
          ),
          decoration: const InputDecoration(
            fillColor: Colors.white,
            counterText: '',
            hintText: 'Viết điều bạn đang nghĩ…',
            contentPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          ),
          onChanged: (value) =>
              widget.workspace.dispatch({'type': 'notes', 'text': value}),
        ),
      ),
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Text(
              '${widget.workspace.notes.length} ký tự',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const Spacer(),
            const Icon(Icons.check_rounded, size: 13, color: Color(0xFF358677)),
            const SizedBox(width: 5),
            const Text(
              'Đã đồng bộ trong phiên',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class DesktopPreviewPage extends StatefulWidget {
  const DesktopPreviewPage({
    super.key,
    required this.workspace,
    this.adaptToViewport = true,
  });
  final WorkspaceController workspace;
  final bool adaptToViewport;
  @override
  State<DesktopPreviewPage> createState() => _DesktopPreviewPageState();
}

class _DesktopPreviewPageState extends State<DesktopPreviewPage> {
  @override
  void dispose() {
    unawaited(leaveFullScreen());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.pop(context),
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF173A46),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      label: const Text('Về điều khiển'),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      key: const ValueKey('preview-fullscreen'),
                      onPressed: () async {
                        final entered = await enterFullScreen();
                        if (!entered && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Trình duyệt không cho phép toàn màn hình. Hãy thử phím F11.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.fullscreen_rounded, size: 17),
                      label: const Text('Toàn màn hình'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DesktopViewport(
                  workspace: widget.workspace,
                  reportSize: widget.adaptToViewport,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
