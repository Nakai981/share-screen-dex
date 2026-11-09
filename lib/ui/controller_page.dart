import 'package:flutter/material.dart';

import '../app.dart';
import '../domain/workspace.dart';
import '../platform/display_bridge.dart';
import 'desktop.dart';
import 'browser/browser_window.dart';
import 'theme.dart';
import 'keyboard_preferences.dart';
import 'hardware_controller_page.dart';
import 'touchpad.dart';

export 'touchpad.dart' show Touchpad;

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key, required this.session});
  final AppSession session;
  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  int _tab = 0;
  bool _drag = false;
  double _sensitivity = 1;
  WorkspaceController get workspace => widget.session.workspace;
  Size? _canvasSize;
  bool _wasPresenting = false;
  bool _showRemote = false;
  @override
  void initState() {
    super.initState();
    _canvasSize = workspace.canvasSize;
    workspace.addListener(_layoutChanged);
    _wasPresenting = widget.session.status.presenting;
    _showRemote = _wasPresenting;
    widget.session.addListener(_connectionChanged);
  }

  void _connectionChanged() {
    final presenting = widget.session.status.presenting;
    if (presenting == _wasPresenting) return;
    setState(() {
      _wasPresenting = presenting;
      _showRemote = presenting;
    });
  }

  void _layoutChanged() {
    if (_canvasSize != workspace.canvasSize) {
      setState(() => _canvasSize = workspace.canvasSize);
    }
  }

  @override
  void dispose() {
    workspace.removeListener(_layoutChanged);
    widget.session.removeListener(_connectionChanged);
    super.dispose();
  }

  void _preview() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DesktopPreviewPage(
        workspace: workspace,
        adaptToViewport: !widget.session.status.presenting,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => _showRemote && widget.session.status.presenting
        ? PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => _showRemote = false);
            },
            child: HardwareControllerPage(
              workspace: workspace,
              fullScreen: true,
              displayName: widget.session.status.name,
              onLeave: () => setState(() => _showRemote = false),
            ),
          )
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Column(
                    children: [
                      _header(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 980;
                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 394,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(
                                        28,
                                        20,
                                        28,
                                        24,
                                      ),
                                      child: _controls(showPreview: false),
                                    ),
                                  ),
                                  Expanded(child: _largePreview()),
                                ],
                              );
                            }
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                24,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 580,
                                  ),
                                  child: _controls(showPreview: true),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );

  Widget _header() => Container(
    height: 78,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.space_dashboard_rounded,
            color: AppColors.mint,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            'SideScreen',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Cách kết nối',
          onPressed: _help,
          icon: const Icon(Icons.help_outline_rounded, size: 21),
        ),
        IconButton(
          tooltip: 'Tùy chỉnh',
          onPressed: _settings,
          icon: const Icon(Icons.tune_rounded, size: 21),
        ),
      ],
    ),
  );

  Widget _controls({required bool showPreview}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showPreview && widget.session.status.presenting) ...[
        Text(
          'Bàn điều khiển',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
      ] else ...[
        Text(
          'Không gian lớn.\nTrong tay bạn.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 13),
        const Text(
          'Biến màn hình ngoài thành góc làm việc của riêng bạn.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 24),
      ],
      _ConnectionStatus(
        status: widget.session.status,
        ready: widget.session.ready,
        onRefresh: () => widget.session.bridge.refresh(),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('open-hardware-controller'),
            icon: const Icon(Icons.keyboard_alt_outlined, size: 17),
            label: const Text(
              'Chuột & bàn phím',
              style: TextStyle(fontSize: 11),
            ),
            onPressed: () {
              if (widget.session.status.presenting) {
                setState(() => _showRemote = true);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HardwareControllerPage(workspace: workspace),
                ),
              );
            },
          ),
          TextButton.icon(
            key: const ValueKey('recover-desktop'),
            icon: const Icon(Icons.restore_rounded, size: 17),
            label: const Text(
              'Khôi phục desktop',
              style: TextStyle(fontSize: 11),
            ),
            onPressed: () => workspace.dispatch({'type': 'recoverDesktop'}),
          ),
        ],
      ),
      if (showPreview && !widget.session.status.presenting) ...[
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Không gian làm việc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.open_in_full_rounded, size: 14),
              label: const Text('Mở rộng', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        _previewFrame(),
      ],
      const SizedBox(height: 28),
      _tabs(),
      const SizedBox(height: 14),
      if (_tab == 0) ...[
        Touchpad(
          workspace: workspace,
          dragging: _drag,
          sensitivity: _sensitivity,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ControlButton(
                icon: Icons.mouse_outlined,
                label: 'Chọn',
                onTap: () => workspace.dispatch({'type': 'click'}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ControlButton(
                icon: Icons.my_location_rounded,
                label: 'Về giữa',
                onTap: () => workspace.dispatch({'type': 'centerPointer'}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Kéo cửa sổ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Di chuột đến thanh tiêu đề rồi vuốt.',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          value: _drag,
          onChanged: (value) {
            workspace.dispatch({'type': 'pointerUp'});
            setState(() => _drag = value);
          },
        ),
      ] else if (_tab == 2)
        BrowserRemoteControls(workspace: workspace)
      else
        _KeyboardEditor(workspace: workspace),
      const SizedBox(height: 16),
      const Divider(height: 1),
      const SizedBox(height: 18),
      _quickActions(),
      if (showPreview && widget.session.status.presenting)
        TextButton.icon(
          onPressed: _preview,
          icon: const Icon(Icons.open_in_full_rounded, size: 15),
          label: const Text(
            'Xem không gian làm việc',
            style: TextStyle(fontSize: 11),
          ),
        ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cable_rounded, color: AppColors.muted, size: 15),
          const SizedBox(width: 7),
          const Flexible(
            child: Text(
              'Kết nối bằng cáp. Không cần tài khoản.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EDF1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final (index, label, icon) in [
          (0, 'Bàn di chuột', Icons.touch_app_outlined),
          (1, 'Bàn phím', Icons.keyboard_outlined),
          (2, 'Trình duyệt', Icons.public_rounded),
        ])
          Expanded(
            child: Semantics(
              selected: _tab == index,
              button: true,
              child: InkWell(
                key: ValueKey('tab-$index'),
                onTap: () {
                  workspace.dispatch({'type': 'pointerUp'});
                  if (index == 1) {
                    workspace.dispatch({'type': 'open', 'app': 'notes'});
                  }
                  if (index == 2) {
                    workspace.dispatch({'type': 'open', 'app': 'browser'});
                  }
                  setState(() => _tab = index);
                },
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  height: 43,
                  decoration: BoxDecoration(
                    color: _tab == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _tab == index
                        ? const [
                            BoxShadow(
                              color: Color(0x0D18313F),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: _tab == index ? AppColors.ink : AppColors.muted,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _tab == index
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _tab == index
                                ? AppColors.ink
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _quickActions() => Row(
    children: [
      Expanded(
        child: _QuickAction(
          icon: Icons.public_rounded,
          label: 'Trình duyệt',
          color: const Color(0xFF378A8E),
          onTap: () {
            workspace.dispatch({'type': 'open', 'app': 'browser'});
            setState(() => _tab = 2);
          },
        ),
      ),
      Expanded(
        child: _QuickAction(
          icon: Icons.edit_note_rounded,
          label: 'Ghi chú',
          color: AppColors.blue,
          onTap: () {
            workspace.dispatch({'type': 'open', 'app': 'notes'});
            setState(() => _tab = 1);
          },
        ),
      ),
      Expanded(
        child: _QuickAction(
          icon: Icons.palette_outlined,
          label: 'Hình nền',
          color: const Color(0xFFB57960),
          onTap: () => workspace.dispatch({'type': 'wallpaper'}),
        ),
      ),
      Expanded(
        child: _QuickAction(
          icon: Icons.auto_awesome_rounded,
          label: 'Bắt đầu',
          color: const Color(0xFF358677),
          onTap: () => workspace.dispatch({'type': 'open', 'app': 'guide'}),
        ),
      ),
    ],
  );

  Widget _previewFrame() => Semantics(
    label: 'Xem trước không gian làm việc. Chạm để mở rộng.',
    button: true,
    child: GestureDetector(
      onTap: _preview,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A18313F),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: workspace.canvasSize.aspectRatio,
            child: DesktopView(workspace: workspace, interactive: false),
          ),
        ),
      ),
    ),
  );

  Widget _largePreview() => Container(
    padding: const EdgeInsets.fromLTRB(38, 28, 38, 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(left: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Một góc nhìn rộng hơn.',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.7,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Mọi thay đổi xuất hiện ngay trong không gian của bạn.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const _Badge(label: 'Xem trước', color: AppColors.blue),
          ],
        ),
        const SizedBox(height: 28),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: workspace.canvasSize.aspectRatio,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2418313F),
                      blurRadius: 40,
                      offset: Offset(0, 22),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DesktopView(workspace: workspace),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF358677),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Cửa sổ linh hoạt. Không gian của bạn.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.open_in_full_rounded, size: 14),
              label: const Text('Mở rộng', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFF358677),
                size: 22,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Mở trình duyệt từ thanh tác vụ, kéo cửa sổ hoặc viết một ghi chú.\n'
                  'Khi cắm màn hình phù hợp, không gian này sẽ tự động xuất hiện ở đó.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.8,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _help() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Từ màn hình nhỏ\nđến ý tưởng lớn.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const _HelpStep(
              number: '1',
              title: 'Chuẩn bị kết nối',
              text:
                  'Điện thoại phải hỗ trợ xuất hình. Dùng cáp USB-C có truyền hình ảnh, hoặc adapter USB-C sang HDMI phù hợp.',
            ),
            const _HelpStep(
              number: '2',
              title: 'Cắm và mở SideScreen',
              text:
                  'Cắm vào màn hình, chọn đúng nguồn vào rồi mở app. Giao diện làm việc tự xuất hiện khi hệ thống cấp màn hình ngoài cho ứng dụng.',
            ),
            const _HelpStep(
              number: '3',
              title: 'Điều khiển từ điện thoại',
              text:
                  'Vuốt bàn di chuột để di chuyển con trỏ. Bật Kéo cửa sổ để sắp xếp. Chọn Bàn phím để viết ghi chú.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Có cổng USB-C chưa có nghĩa là xuất được hình. Khả năng này tùy mẫu điện thoại. '
                'Trên iPhone, hãy dùng điện thoại để điều khiển giao diện trên màn hình ngoài.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: Color(0xFF87633C),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, updateSheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Theo cách của bạn',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Tốc độ con trỏ'),
                  const Spacer(),
                  Text('${_sensitivity.toStringAsFixed(1)}×'),
                ],
              ),
              Slider(
                value: _sensitivity,
                min: .5,
                max: 2,
                divisions: 6,
                label: '${_sensitivity.toStringAsFixed(1)}×',
                onChanged: (value) {
                  setState(() => _sensitivity = value);
                  updateSheet(() {});
                },
              ),
              const Divider(),
              SwitchListTile(
                key: const ValueKey('external-fullscreen'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Phủ kín màn hình ngoài',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Tự bố trí theo tỷ lệ màn hình, không cắt nội dung. Tắt để giữ tỷ lệ 16:10.',
                  style: TextStyle(fontSize: 11),
                ),
                value: workspace.fullScreen,
                onChanged: (enabled) {
                  workspace.dispatch({
                    'type': 'fullScreen',
                    'enabled': enabled,
                  });
                  updateSheet(() {});
                },
              ),
              const SizedBox(height: 12),
              KeyboardPreferences(workspace: workspace),
              const SizedBox(height: 16),
              const Text('Kích thước con trỏ', style: TextStyle(fontSize: 12)),
              Slider(
                key: const ValueKey('cursor-scale'),
                value: workspace.cursorScale,
                min: .7,
                max: 1.5,
                divisions: 8,
                onChanged: (value) {
                  workspace.dispatch({'type': 'cursorScale', 'value': value});
                  updateSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Viền an toàn dưới màn hình: ${workspace.safeInset.round()}',
                style: const TextStyle(fontSize: 12),
              ),
              const Text(
                'Tăng nếu taskbar bị màn hình ngoài cắt ở mép dưới.',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              Slider(
                key: const ValueKey('display-safe-inset'),
                value: workspace.safeInset,
                min: 4,
                max: 96,
                divisions: 10,
                onChanged: (value) {
                  workspace.dispatch({'type': 'safeInset', 'value': value});
                  updateSheet(() {});
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text(
                  'Đổi hình nền',
                  style: TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => workspace.dispatch({'type': 'wallpaper'}),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text(
                  'Sắp xếp lại cửa sổ',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Giữ nguyên nội dung ghi chú.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                onTap: () {
                  workspace.dispatch({'type': 'arrange'});
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              Text(
                widget.session.status.nativeAvailable
                    ? 'SideScreen 0.8 · Màn hình có dây'
                    : 'SideScreen 0.8 · Chế độ xem thử',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    required this.status,
    required this.ready,
    required this.onRefresh,
  });
  final DisplayStatus status;
  final bool ready;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final active = status.presenting;
    final color = active ? const Color(0xFF358677) : AppColors.blue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              active ? Icons.desktop_windows_outlined : Icons.cable_rounded,
              color: color,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !ready
                      ? 'Đang kiểm tra kết nối…'
                      : active
                      ? 'Màn hình đã sẵn sàng'
                      : status.error != null
                      ? 'Chưa thể mở màn hình'
                      : status.connected
                      ? 'Đang mở không gian…'
                      : 'Sẵn sàng khi bạn kết nối',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  active
                      ? '${status.name ?? 'Màn hình ngoài'}${status.width != null ? '\n${status.width} × ${status.height}' : ''}'
                      : status.error != null
                      ? 'Chạm nút bên cạnh để thử lại. Nếu chưa được, đóng rồi mở app.'
                      : status.nativeAvailable
                      ? 'Cắm màn hình qua USB-C / HDMI.'
                      : 'Bạn đang dùng chế độ xem thử.',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.65,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (status.nativeAvailable)
            SizedBox(
              width: 28,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Kiểm tra lại kết nối',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
            )
          else
            const _Badge(label: 'Xem thử', color: AppColors.blue),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
    ),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.line),
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _KeyboardEditor extends StatefulWidget {
  const _KeyboardEditor({required this.workspace});
  final WorkspaceController workspace;
  @override
  State<_KeyboardEditor> createState() => _KeyboardEditorState();
}

class _KeyboardEditorState extends State<_KeyboardEditor> {
  late KeyboardLanguage _language;
  late final SyncedTextController text = SyncedTextController(
    text: widget.workspace.notes,
  );
  @override
  void initState() {
    super.initState();
    _language = widget.workspace.keyboardLanguage;
    widget.workspace.addListener(_sync);
  }

  void _sync() {
    text.syncRemote(widget.workspace.notes);
    if (_language != widget.workspace.keyboardLanguage) {
      setState(() => _language = widget.workspace.keyboardLanguage);
    }
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_sync);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 18, color: AppColors.blue),
            SizedBox(width: 7),
            Text(
              'Nội dung ghi chú',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      TextField(
        key: const ValueKey('phone-notes'),
        controller: text,
        minLines: 7,
        maxLines: 9,
        maxLength: 50000,
        textCapitalization: TextCapitalization.sentences,
        hintLocales: widget.workspace.keyboardLanguage.hintLocales,
        keyboardType: TextInputType.multiline,
        autocorrect: true,
        enableSuggestions: true,
        style: const TextStyle(fontSize: 13, height: 1.9),
        decoration: InputDecoration(
          hintText: 'Viết điều bạn đang nghĩ…',
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.blue),
          ),
        ),
        onChanged: (value) =>
            widget.workspace.dispatch({'type': 'notes', 'text': value}),
      ),
      const SizedBox(height: 2),
      const SizedBox(height: 12),
      KeyboardPreferences(workspace: widget.workspace),
      const Text(
        'Nội dung xuất hiện ngay trong cửa sổ Ghi chú.',
        style: TextStyle(fontSize: 10, color: AppColors.muted),
      ),
    ],
  );
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({
    required this.number,
    required this.title,
    required this.text,
  });
  final String number;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.8,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
