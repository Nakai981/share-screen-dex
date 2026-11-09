import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/workspace.dart';
import 'display_bridge.dart';

class ChromeLaunchException implements Exception {
  const ChromeLaunchException(this.message);
  final String message;
}

Uri chromeLaunchAddress(String current) {
  if (current == browserHome) return Uri.https('www.google.com', '/');
  if (current == browserDemo) {
    throw const ChromeLaunchException(
      'Trang thử cục bộ chỉ mở trong Trình duyệt SideScreen.',
    );
  }
  final uri = Uri.tryParse(current);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    throw const ChromeLaunchException(
      'Hãy mở một địa chỉ http hoặc https trước.',
    );
  }
  return uri;
}

class ChromeLauncher {
  static const _channel = MethodChannel(DisplayBridge.channelName);
  static bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);

  static Future<void> open(String current) async {
    if (!supported) {
      throw const ChromeLaunchException(
        'Mở Chrome từ ứng dụng Android/iPhone.',
      );
    }
    final uri = chromeLaunchAddress(current);
    try {
      await _channel.invokeMethod<void>('openChrome', {'url': uri.toString()});
    } on MissingPluginException {
      throw const ChromeLaunchException(
        'Cần cài lại đầy đủ bản SideScreen mới để mở Chrome.',
      );
    } on PlatformException catch (error) {
      throw ChromeLaunchException(
        error.message ?? 'Không mở được Chrome trên điện thoại.',
      );
    }
  }
}
