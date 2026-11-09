import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/workspace.dart';
import '../theme.dart';
import 'browser_surface.dart';
import 'browser_web_navigation.dart';
import '../keyboard_preferences.dart';

class BrowserWindow extends StatelessWidget {
  const BrowserWindow({
    super.key,
    required this.workspace,
    this.interactive = true,
    this.windowWidth = 1440,
  });
  final WorkspaceController workspace;
  final bool interactive;
  final double windowWidth;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      PointerInterceptor(
        child: SizedBox(
          key: const ValueKey('browser-toolbar'),
          height: browserToolbarHeight,
          child: ColoredBox(
            color: const Color(0xFFF1F5F7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _NavButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Quay lại',
                    enabled: workspace.browserCanGoBack,
                    onTap: () => workspace.dispatch({'type': 'browserBack'}),
                  ),
                  _NavButton(
                    icon: Icons.arrow_forward_rounded,
                    label: 'Tiến tới',
                    enabled: workspace.browserCanGoForward,
                    onTap: () => workspace.dispatch({'type': 'browserForward'}),
                  ),
                  _NavButton(
                    icon: Icons.refresh_rounded,
                    label: 'Tải lại',
                    onTap: () => workspace.dispatch({'type': 'browserReload'}),
                  ),
                  _NavButton(
                    icon: Icons.home_outlined,
                    label: 'Trang chủ',
                    onTap: () => workspace.dispatch({'type': 'browserHome'}),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: BrowserAddressField(
                      workspace: workspace,
                      id: 'desktop',
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    key: const ValueKey('browser-exit-video'),
                    width: browserExitWidth(windowWidth),
                    child: Tooltip(
                      message: 'Thu nhỏ video',
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(36, 36),
                          backgroundColor: const Color(0xFFE0ECE9),
                        ),
                        onPressed: () => workspace.dispatch({
                          'type': 'browserExitFullscreen',
                        }),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.fullscreen_exit_rounded, size: 18),
                            if (windowWidth >= 600) ...[
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  'Thu nhỏ video',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ],
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
      if (workspace.browserError != null)
        PointerInterceptor(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFFFF2E7),
            child: Text(
              workspace.browserError!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF87633C)),
            ),
          ),
        ),
      Expanded(
        child: workspace.browserUrl == browserHome
            ? _BrowserHome(workspace: workspace)
            : kIsWeb &&
                  [
                    'google.com',
                    'www.google.com',
                    'facebook.com',
                    'www.facebook.com',
                    'm.facebook.com',
                  ].contains(Uri.tryParse(workspace.browserUrl)?.host)
            ? _ExternalWebPage(url: workspace.browserUrl)
            : kIsWeb && needsYouTubeExternalPage(workspace.browserUrl)
            ? _YouTubeWebPage(workspace: workspace)
            : browserSurface(
                workspace: workspace,
                url: workspace.browserUrl,
                reload: workspace.browserReload,
                interactive:
                    interactive && workspace.activeApp == DeskApp.browser,
                command: workspace.browserCommand,
                onNavigate: (url, replace) => workspace.dispatch({
                  'type': 'browserLocation',
                  'url': url,
                  'replace': replace,
                }),
              ),
      ),
      PointerInterceptor(
        child: Container(
          height: browserFooterHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9FA),
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.public_rounded,
                size: 12,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kIsWeb
                      ? isYouTubeAddress(workspace.browserUrl)
                            ? 'Video không phát? Thử mở trên YouTube.'
                            : 'Trang không hiển thị? Thử mở bằng tab ngoài.'
                      : 'Duyệt web trong không gian của bạn.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ),
              if (kIsWeb && workspace.browserUrl.startsWith('http'))
                TextButton.icon(
                  onPressed: () => _openExternal(context, workspace.browserUrl),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(30, 22),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 12),
                  label: const Text(
                    'Mở tab ngoài',
                    style: TextStyle(fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

Future<void> _openExternal(BuildContext context, String url) async {
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Hãy thử một địa chỉ khác.'),
      ),
    );
  }
}

class BrowserAddressField extends StatefulWidget {
  const BrowserAddressField({
    super.key,
    required this.workspace,
    required this.id,
    this.focusNode,
    this.onSubmitted,
    this.compact = false,
  });
  final WorkspaceController workspace;
  final String id;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final bool compact;
  @override
  State<BrowserAddressField> createState() => _BrowserAddressFieldState();
}

class _BrowserAddressFieldState extends State<BrowserAddressField> {
  final localFocus = FocusNode();
  FocusNode get focus => widget.focusNode ?? localFocus;
  int focusSerial = -1;
  bool syncing = false;
  bool get mirror => widget.workspace.forwardAction != null;
  late String lastUrl = widget.workspace.browserUrl;
  late final text = TextEditingController(
    text: lastUrl == browserHome ? '' : lastUrl,
  );
  @override
  void initState() {
    super.initState();
    widget.workspace.addListener(_sync);
    text.addListener(_edited);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  void _sync() {
    final workspace = widget.workspace;
    if (workspace.activeApp != DeskApp.browser) {
      if (focus.hasFocus) focus.unfocus();
      return;
    }
    if (workspace.browserAddressEditing) {
      syncing = true;
      if (text.text != workspace.browserAddressDraft ||
          (mirror &&
              text.selection.extentOffset != workspace.browserAddressCaret)) {
        text.value = TextEditingValue(
          text: workspace.browserAddressDraft,
          selection: TextSelection.collapsed(
            offset: workspace.browserAddressCaret,
          ),
        );
      }
      syncing = false;
      if (focusSerial != workspace.browserAddressFocusSerial &&
          widget.id == 'desktop' &&
          (mirror || workspace.browserAddressSource == 'desktop')) {
        focusSerial = workspace.browserAddressFocusSerial;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.workspace.browserAddressEditing) {
            focus.requestFocus();
          }
        });
      }
      return;
    }
    if (mirror && focus.hasFocus) focus.unfocus();
    final url = widget.workspace.browserUrl;
    if (url == lastUrl) return;
    lastUrl = url;
    text.text = url == browserHome ? '' : url;
  }

  void _edited() {
    final workspace = widget.workspace;
    if (syncing ||
        mirror ||
        !focus.hasFocus ||
        !workspace.browserAddressEditing) {
      return;
    }
    final caret = text.selection.extentOffset.clamp(0, text.text.length);
    if (workspace.browserAddressDraft == text.text &&
        workspace.browserAddressCaret == caret) {
      return;
    }
    workspace.dispatch({
      'type': 'browserAddressDraft',
      'text': text.text,
      'caret': caret,
    });
  }

  void _go() {
    widget.workspace.dispatch({'type': 'browserNavigate', 'url': text.text});
    FocusScope.of(context).unfocus();
    if (widget.workspace.browserError == null) widget.onSubmitted?.call();
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_sync);
    localFocus.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey('browser-address-${widget.id}'),
    controller: text,
    focusNode: focus,
    readOnly: mirror,
    showCursor: true,
    cursorColor: AppColors.blue,
    cursorWidth: 2,
    onTap: () {
      widget.workspace.dispatch({
        'type': 'browserFocusAddress',
        'source': widget.id,
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
    },
    keyboardType: TextInputType.text,
    hintLocales: widget.workspace.keyboardLanguage.hintLocales,
    textInputAction: TextInputAction.go,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Tìm với Google hoặc nhập địa chỉ',
      fillColor: Colors.white,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: widget.compact ? 8 : 13,
      ),
      prefixIcon: Icon(
        widget.workspace.browserUrl.startsWith('https:')
            ? Icons.lock_outline_rounded
            : Icons.search_rounded,
        size: 16,
        color: AppColors.muted,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      suffixIcon: IconButton(
        constraints: widget.compact
            ? const BoxConstraints.tightFor(width: 30, height: 30)
            : null,
        padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(8),
        tooltip: 'Đi đến địa chỉ',
        onPressed: _go,
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.blue),
      ),
    ),
    onSubmitted: (_) => _go(),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32,
    height: 36,
    child: IconButton(
      tooltip: label,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 18),
    ),
  );
}

class _BrowserHome extends StatelessWidget {
  const _BrowserHome({required this.workspace});
  final WorkspaceController workspace;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF7FAFA),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEFEA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  size: 35,
                  color: Color(0xFF358677),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Mở một góc nhìn mới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Website, ý tưởng và những điều bạn đang tìm kiếm.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 26),
              BrowserAddressField(workspace: workspace, id: 'home'),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SiteTile(
                    icon: Icons.science_outlined,
                    title: 'Trang thử',
                    subtitle: 'Thử tương tác, không cần mạng',
                    onTap: () => workspace.dispatch({
                      'type': 'browserNavigate',
                      'url': browserDemo,
                    }),
                  ),
                  _SiteTile(
                    icon: Icons.search_rounded,
                    title: 'Google',
                    subtitle: 'Tìm kiếm trên Google',
                    onTap: () => workspace.dispatch({
                      'type': 'browserNavigate',
                      'url': 'https://www.google.com',
                    }),
                  ),
                  _SiteTile(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'YouTube',
                    subtitle: 'Website video',
                    onTap: () => workspace.dispatch({
                      'type': 'browserNavigate',
                      'url': 'https://www.youtube.com',
                    }),
                  ),
                  _SiteTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Facebook',
                    subtitle: 'Website mạng xã hội',
                    onTap: () => workspace.dispatch({
                      'type': 'browserNavigate',
                      'url': 'https://www.facebook.com',
                    }),
                  ),
                  _SiteTile(
                    icon: Icons.language_rounded,
                    title: 'Wikipedia',
                    subtitle: 'Khám phá kiến thức',
                    onTap: () => workspace.dispatch({
                      'type': 'browserNavigate',
                      'url': 'https://www.wikipedia.org',
                    }),
                  ),
                  _SiteTile(
                    icon: Icons.code_rounded,
                    title: 'Example',
                    subtitle: 'Mở một website mẫu',
                    onTap: () => workspace.dispatch({
                      'type': 'browserNavigate',
                      'url': 'https://example.com',
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _YouTubeWebPage extends StatelessWidget {
  const _YouTubeWebPage({required this.workspace});
  final WorkspaceController workspace;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              size: 48,
              color: Color(0xFFE43C36),
            ),
            const SizedBox(height: 18),
            const Text(
              'Mở YouTube',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: const Text(
                'Trong bản xem thử trên web, trang chủ và tìm kiếm YouTube mở bằng tab riêng. Dán liên kết một video vào thanh địa chỉ để xem bằng trình phát nhúng tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _openExternal(context, workspace.browserUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Mở YouTube trong tab riêng'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Một số video không cho phép phát nhúng; khi đó hãy dùng tab riêng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExternalWebPage extends StatelessWidget {
  const _ExternalWebPage({required this.url});
  final String url;
  String get site =>
      Uri.parse(url).host.endsWith('facebook.com') ? 'Facebook' : 'Google';
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 40, color: AppColors.blue),
            const SizedBox(height: 18),
            Text(
              'Mở $site',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              Uri.parse(url).queryParameters['q'] ?? Uri.parse(url).host,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                '$site mở trong tab riêng khi xem thử trên web. Trên app điện thoại, website mở trong cửa sổ trình duyệt này.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _openExternal(context, url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Mở $site'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SiteTile extends StatefulWidget {
  const _SiteTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  State<_SiteTile> createState() => _SiteTileState();
}

class _SiteTileState extends State<_SiteTile> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        width: 192,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: hovered ? const Color(0xFFEAF3F0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hovered ? AppColors.mint : AppColors.line),
        ),
        child: Column(
          children: [
            Icon(widget.icon, size: 24, color: const Color(0xFF358677)),
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class BrowserRemoteControls extends StatelessWidget {
  const BrowserRemoteControls({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workspace,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Địa chỉ trên màn hình lớn',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        BrowserAddressField(workspace: workspace, id: 'phone'),
        if (workspace.browserError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              workspace.browserError!,
              style: const TextStyle(fontSize: 11, color: Colors.deepOrange),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              icon: Icons.arrow_back_rounded,
              label: 'Quay lại',
              enabled: workspace.browserCanGoBack,
              onTap: () => workspace.dispatch({'type': 'browserBack'}),
            ),
            _NavButton(
              icon: Icons.arrow_forward_rounded,
              label: 'Tiến tới',
              enabled: workspace.browserCanGoForward,
              onTap: () => workspace.dispatch({'type': 'browserForward'}),
            ),
            _NavButton(
              icon: Icons.refresh_rounded,
              label: 'Tải lại',
              onTap: () => workspace.dispatch({'type': 'browserReload'}),
            ),
            _NavButton(
              icon: Icons.home_outlined,
              label: 'Trang chủ',
              onTap: () => workspace.dispatch({'type': 'browserHome'}),
            ),
            _NavButton(
              icon: Icons.science_outlined,
              label: 'Mở trang thử',
              onTap: () => workspace.dispatch({
                'type': 'browserNavigate',
                'url': browserDemo,
              }),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: const Text('Cuộn lên', style: TextStyle(fontSize: 11)),
                onPressed: () =>
                    workspace.dispatch({'type': 'browserScroll', 'dy': -380}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: const Text('Cuộn xuống', style: TextStyle(fontSize: 11)),
                onPressed: () =>
                    workspace.dispatch({'type': 'browserScroll', 'dy': 380}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BrowserPageInput(workspace: workspace),
        const SizedBox(height: 12),
        KeyboardPreferences(workspace: workspace),
        const SizedBox(height: 14),
        const Text(
          'Dùng Bàn di chuột để chọn nội dung trong trang.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bản xem thử: bạn có thể dùng chuột trực tiếp trong trang web.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
      ],
    ),
  );
}

class _BrowserPageInput extends StatefulWidget {
  const _BrowserPageInput({required this.workspace});
  final WorkspaceController workspace;
  @override
  State<_BrowserPageInput> createState() => _BrowserPageInputState();
}

class _BrowserPageInputState extends State<_BrowserPageInput> {
  final text = TextEditingController();
  void _send() {
    widget.workspace.dispatch({'type': 'browserText', 'text': text.text});
    text.clear();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: text,
    key: const ValueKey('browser-page-input'),
    textInputAction: TextInputAction.send,
    keyboardType: TextInputType.multiline,
    minLines: 1,
    maxLines: 4,
    hintLocales: widget.workspace.keyboardLanguage.hintLocales,
    autocorrect: true,
    enableSuggestions: true,
    decoration: InputDecoration(
      labelText: 'Nhập vào ô đang chọn trên trang',
      labelStyle: const TextStyle(fontSize: 11),
      suffixIcon: IconButton(
        tooltip: 'Gửi vào trang',
        onPressed: _send,
        icon: const Icon(Icons.send_rounded, size: 18),
      ),
    ),
    onSubmitted: (_) => _send(),
  );
}
