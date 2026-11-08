import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<bool> enterFullScreen() async {
  try {
    await web.document.documentElement!.requestFullscreen().toDart;
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> leaveFullScreen() async {
  if (web.document.fullscreenElement != null) {
    await web.document.exitFullscreen().toDart;
  }
}
