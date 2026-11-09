import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../domain/workspace.dart';
import 'browser_content.dart';
import 'browser_web_navigation.dart';
import 'browser_desktop_script.dart';

Widget browserSurface({
  required String url,
  required int reload,
  required bool interactive,
  required void Function(String url, bool replace) onNavigate,
  Map<String, Object?>? command,
  WorkspaceController? workspace,
}) => _WebSurface(
  url: url,
  reload: reload,
  interactive: interactive,
  command: command,
);

class _WebSurface extends StatefulWidget {
  const _WebSurface({
    required this.url,
    required this.reload,
    required this.interactive,
    this.command,
  });
  final String url;
  final int reload;
  final bool interactive;
  final Map<String, Object?>? command;
  @override
  State<_WebSurface> createState() => _WebSurfaceState();
}

class _WebSurfaceState extends State<_WebSurface> {
  web.HTMLIFrameElement? frame;
  StreamSubscription<web.Event>? load;
  bool loading = true;
  @override
  void didUpdateWidget(_WebSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.reload != oldWidget.reload) {
      _navigate();
    }
    frame?.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    if (widget.command?['serial'] != oldWidget.command?['serial'] &&
        widget.command != null) {
      frame?.contentWindow?.postMessage(
        {'source': 'sidescreen', 'command': widget.command}.jsify(),
        '*'.toJS,
      );
    }
  }

  void _navigate() {
    if (frame == null) return;
    loading = true;
    if (widget.url == browserDemo) {
      // This HTML is bundled application code, not user-provided markup.
      frame!.removeAttribute('sandbox');
      frame!.srcdoc = browserDemoHtml
          .replaceFirst(
            '</head>',
            '<script>$browserDesktopFullscreenScript</script></head>',
          )
          .toJS;
    } else {
      frame!.setAttribute(
        'sandbox',
        'allow-scripts allow-forms allow-popups allow-same-origin',
      );
      frame!.removeAttribute('srcdoc');
      frame!.src =
          youTubePlayerAddress(
            widget.url,
            origin: web.window.location.origin,
          )?.toString() ??
          widget.url;
    }
  }

  @override
  void dispose() {
    load?.cancel();
    frame?.src = 'about:blank';
    frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: HtmlElementView.fromTagName(
          tagName: 'iframe',
          onElementCreated: (element) {
            final next = element as web.HTMLIFrameElement;
            frame = next;
            next.title = 'Nội dung trang web';
            next.referrerPolicy = 'strict-origin-when-cross-origin';
            next.allow =
                'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
            next.allowFullscreen = true;
            next.style
              ..width = '100%'
              ..height = '100%'
              ..border = '0'
              ..backgroundColor = '#ffffff'
              ..pointerEvents = widget.interactive ? 'auto' : 'none';
            load = next.onLoad.listen((_) {
              if (mounted) setState(() => loading = false);
            });
            _navigate();
          },
        ),
      ),
      if (loading)
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(value: .35, minHeight: 2),
        ),
    ],
  );
}
