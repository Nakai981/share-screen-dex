/// Web preview cannot load YouTube's full site in an iframe. Only the official
/// embedded player is supported; the original address stays in browser history.
bool isYouTubeAddress(String address) {
  final uri = Uri.tryParse(address);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) return false;
  final host = uri.host.toLowerCase();
  return host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtu.be' ||
      host == 'www.youtu.be' ||
      host == 'youtube-nocookie.com' ||
      host == 'www.youtube-nocookie.com';
}

Uri? youTubePlayerAddress(String address, {String? origin}) {
  if (!isYouTubeAddress(address)) return null;
  final uri = Uri.parse(address);
  final path = uri.pathSegments;
  String? id;
  if (['youtu.be', 'www.youtu.be'].contains(uri.host.toLowerCase())) {
    id = path.firstOrNull;
  } else if (path.firstOrNull == 'watch') {
    id = uri.queryParameters['v'];
  } else if (path.length >= 2 &&
      ['embed', 'shorts', 'live'].contains(path.first)) {
    id = path[1];
  }
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
  final params = <String, String>{'playsinline': '1'};
  final time = uri.queryParameters['start'] ?? uri.queryParameters['t'];
  if (time != null) {
    final numeric = int.tryParse(time);
    final duration = RegExp(
      r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$',
    ).firstMatch(time);
    final seconds =
        numeric ??
        (duration == null
            ? 0
            : (int.tryParse(duration[1] ?? '') ?? 0) * 3600 +
                  (int.tryParse(duration[2] ?? '') ?? 0) * 60 +
                  (int.tryParse(duration[3] ?? '') ?? 0));
    if (seconds > 0) params['start'] = seconds.clamp(0, 2147483647).toString();
  }
  final page = origin == null ? null : Uri.tryParse(origin);
  if (page != null &&
      ['http', 'https'].contains(page.scheme) &&
      page.host.isNotEmpty) {
    params['origin'] = page.origin;
  }
  return Uri.https('www.youtube.com', '/embed/$id', params);
}

bool needsYouTubeExternalPage(String address) =>
    isYouTubeAddress(address) && youTubePlayerAddress(address) == null;
