/// Convert supported app hand-off links back to websites. Never launch an
/// external application from a page navigation or a popup.
Uri? browserWebDestination(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty) return uri;
  if (['youtube', 'vnd.youtube'].contains(uri.scheme)) {
    // Uri.host lowercases characters, while a YouTube video ID is case-sensitive.
    final authorityId = RegExp(r'^[^:]+://([^/?#]+)').firstMatch(value)?[1];
    final id =
        uri.queryParameters['v'] ??
        (uri.host == 'watch'
            ? uri.pathSegments.firstOrNull
            : uri.host.isNotEmpty
            ? authorityId
            : uri.pathSegments.firstOrNull);
    if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      return Uri.https('www.youtube.com', '/watch', {'v': id});
    }
    return Uri.https('www.youtube.com', '/');
  }
  if (uri.scheme == 'fb') {
    final href = Uri.tryParse(uri.queryParameters['href'] ?? '');
    if (href != null &&
        ['http', 'https'].contains(href.scheme) &&
        href.host.isNotEmpty) {
      return href;
    }
    final id = uri.pathSegments.firstOrNull ?? uri.queryParameters['id'];
    if (['profile', 'page'].contains(uri.host) &&
        id != null &&
        RegExp(r'^\d+$').hasMatch(id)) {
      return Uri.https('www.facebook.com', '/$id');
    }
    return Uri.https('www.facebook.com', '/');
  }
  if (uri.scheme == 'intent') {
    final fallback = RegExp(
      r'(?:^|;)S\.browser_fallback_url=([^;]+)',
    ).firstMatch(uri.fragment);
    if (fallback != null) {
      try {
        final target = Uri.tryParse(Uri.decodeComponent(fallback[1]!));
        if (target != null &&
            ['http', 'https'].contains(target.scheme) &&
            target.host.isNotEmpty) {
          return target;
        }
      } on FormatException {
        return null;
      }
    }
    final scheme = RegExp(
      r'(?:^|;)scheme=(https?)\b',
    ).firstMatch(uri.fragment)?[1];
    if (scheme != null && uri.host.isNotEmpty) {
      return uri.replace(scheme: scheme).removeFragment();
    }
  }
  return null;
}

String desktopBrowserUserAgent(String? current) {
  final agent = current ?? '';
  final chrome = RegExp(r'Chrome/([\d.]+)').firstMatch(agent)?[1];
  if (chrome != null) {
    return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chrome Safari/537.36';
  }
  final webkit =
      RegExp(r'AppleWebKit/([\d.]+)').firstMatch(agent)?[1] ?? '605.1.15';
  final version =
      RegExp(r'Version/([\d.]+)').firstMatch(agent)?[1] ??
      '${RegExp(r'(?:iPhone OS|CPU OS) (\d+)').firstMatch(agent)?[1] ?? '18'}.0';
  return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/$webkit (KHTML, like Gecko) Version/$version Safari/$webkit';
}

const browserInAppNavigationScript = r'''
(() => {
  if (window.__sideScreenDesktopNavigation) return;
  window.__sideScreenDesktopNavigation = true;
  const send = value => {
    try { window.SideScreenBrowser.postMessage(new URL(String(value), location.href).href); } catch (_) {}
  };
  window.open = url => { if (url) send(url); return null; };
  document.addEventListener('click', e => {
    const a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a || a.hasAttribute('download') || a.getAttribute('href').startsWith('#') || a.href.startsWith('javascript:')) return;
    const url = new URL(a.href, location.href);
    const http = ['http:', 'https:'].includes(url.protocol);
    const appSite = /(^|\.)(youtube\.com|youtu\.be|facebook\.com)$/.test(url.hostname);
    // Leave normal links, Google redirects and form/SPA handlers to the page.
    // Only take over app hand-offs and new-window links.
    if (http && !appSite && a.target !== '_blank') return;
    e.preventDefault();
    send(a.href);
  }, true);
  const inline = node => {
    if (!node || node.nodeType !== 1) return;
    if (node.matches('video')) node.setAttribute('playsinline', '');
    node.querySelectorAll('video').forEach(video => video.setAttribute('playsinline', ''));
  };
  inline(document.documentElement);
  new MutationObserver(records => records.forEach(r => r.addedNodes.forEach(inline)))
    .observe(document.documentElement, {childList:true, subtree:true});
})();
''';
