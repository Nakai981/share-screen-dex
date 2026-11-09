import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../domain/workspace.dart';
import '../theme.dart';
import 'browser_content.dart';
import 'browser_navigation_policy.dart';

Widget browserSurface({
  required String url,
  required int reload,
  required bool interactive,
  required void Function(String url, bool replace) onNavigate,
  Map<String, Object?>? command,
}) => _NativeSurface(
  url: url,
  reload: reload,
  interactive: interactive,
  onNavigate: onNavigate,
  command: command,
);

class _NativeSurface extends StatefulWidget {
  const _NativeSurface({
    required this.url,
    required this.reload,
    required this.interactive,
    required this.onNavigate,
    this.command,
  });
  final String url;
  final int reload;
  final bool interactive;
  final void Function(String url, bool replace) onNavigate;
  final Map<String, Object?>? command;
  @override
  State<_NativeSurface> createState() => _NativeSurfaceState();
}

class _NativeSurfaceState extends State<_NativeSurface> {
  WebViewController? controller;
  String? error;
  String? loadedUrl;
  int progress = 0;
  bool pageLoading = false;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (![
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform)) {
      setState(() => error = 'Trình duyệt nhúng hỗ trợ Android và iOS.');
      return;
    }
    try {
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            )
          : const PlatformWebViewControllerCreationParams();
      final next = WebViewController.fromPlatformCreationParams(params);
      controller = next;
      await next.setJavaScriptMode(JavaScriptMode.unrestricted);
      await next.setBackgroundColor(Colors.white);
      String? userAgent;
      try {
        userAgent = await next.getUserAgent();
      } catch (_) {}
      await next.setUserAgent(desktopBrowserUserAgent(userAgent));
      await next.addJavaScriptChannel(
        'SideScreenBrowser',
        onMessageReceived: (message) {
          final target = browserWebDestination(message.message);
          if (target != null) _openWebLink(target);
        },
      );
      await next.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            if (url.startsWith('http://') || url.startsWith('https://')) {
              loadedUrl = url;
              if (url != widget.url) widget.onNavigate(url, true);
            }
          },
          onPageFinished: (_) {
            pageLoading = false;
            if (mounted) {
              setState(() => progress = 100);
              unawaited(
                controller
                        ?.runJavaScript(browserInAppNavigationScript)
                        .catchError((_) {}) ??
                    Future<void>.value(),
              );
            }
          },
          onWebResourceError: (failure) {
            if (failure.errorCode == -999) {
              return; // A replaced WebKit navigation was cancelled.
            }
            if (mounted && failure.isForMainFrame != false) {
              setState(
                () => error =
                    'Không tải được trang. Kiểm tra kết nối rồi thử lại.',
              );
            }
          },
          onNavigationRequest: (request) {
            if (!mounted) return NavigationDecision.prevent;
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                !['http', 'https', 'about'].contains(uri.scheme)) {
              final target = browserWebDestination(request.url);
              if (target != null) _openWebLink(target);
              return NavigationDecision.prevent;
            }
            if (uri != null &&
                ['https', 'http'].contains(uri.scheme) &&
                request.isMainFrame &&
                request.url != loadedUrl &&
                !pageLoading) {
              loadedUrl = request.url;
              pageLoading = true;
              widget.onNavigate(request.url, false);
            }
            return uri != null &&
                    ['https', 'http', 'about'].contains(uri.scheme)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      if (mounted) {
        await _navigate();
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Không khởi tạo được trình duyệt nhúng trên thiết bị này.',
        );
      }
    }
  }

  void _openWebLink(Uri uri) {
    // Run after the navigation decision/JS callback has completed. Native
    // loadRequest keeps universal links inside WKWebView instead of an app.
    Timer.run(() {
      if (!mounted || controller == null) return;
      loadedUrl = uri.toString();
      pageLoading = true;
      setState(() {
        error = null;
        progress = 0;
      });
      widget.onNavigate(loadedUrl!, false);
      unawaited(
        controller!.loadRequest(uri).catchError((_) {
          if (mounted) {
            setState(() => error = 'Không tải được trang. Hãy thử lại.');
          }
        }),
      );
    });
  }

  Future<void> _navigate() async {
    if (controller == null) return;
    error = null;
    progress = 0;
    loadedUrl = widget.url;
    pageLoading = true;
    try {
      if (widget.url == browserDemo) {
        await controller!.loadHtmlString(browserDemoHtml);
      } else {
        await controller!.loadRequest(Uri.parse(widget.url));
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Không tải được trang. Hãy thử lại.');
    }
  }

  @override
  void didUpdateWidget(_NativeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != loadedUrl || widget.reload != oldWidget.reload) {
      unawaited(_navigate());
    }
    if (widget.command?['serial'] != oldWidget.command?['serial'] &&
        widget.command != null) {
      unawaited(
        controller
                ?.runJavaScript(browserCommandScript(widget.command!))
                .catchError((_) {}) ??
            Future<void>.value(),
      );
    }
  }

  @override
  void dispose() {
    controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ColoredBox(
        color: AppColors.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.public_off_rounded,
                  size: 34,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 16),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => unawaited(
                    controller == null ? _initialize() : _navigate(),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (controller == null) return const ColoredBox(color: Colors.white);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.interactive,
            child: WebViewWidget(controller: controller!),
          ),
        ),
        if (progress < 100)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(value: progress / 100, minHeight: 2),
          ),
      ],
    );
  }
}
