import 'package:flutter/services.dart';

Future<bool> enterFullScreen() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  return true;
}

Future<void> leaveFullScreen() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
