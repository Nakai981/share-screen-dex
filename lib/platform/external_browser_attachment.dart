import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'display_bridge.dart';

bool usesExternalBrowserHost({required bool external}) =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && external;

/// Keeps the plugin controller, but lets UIKit place its WKWebView directly in
/// the external scene instead of Flutter's main-screen-scaled platform view.
class ExternalBrowserAttachment {
  static const _channel = MethodChannel(DisplayBridge.channelName);
  int? _identifier;

  Future<void> attach(int identifier) async {
    _identifier = identifier;
    await _channel.invokeMethod<void>('attachExternalBrowser', {
      'identifier': identifier,
    });
  }

  Future<void> present({required bool visible, required int progress}) async {
    final identifier = _identifier;
    if (identifier == null) return;
    await _channel.invokeMethod<void>('updateExternalBrowser', {
      'identifier': identifier,
      'visible': visible,
      'progress': progress,
    });
  }

  Future<void> detach() async {
    final identifier = _identifier;
    _identifier = null;
    if (identifier == null) return;
    await _channel.invokeMethod<void>('detachExternalBrowser', {
      'identifier': identifier,
    });
  }
}
