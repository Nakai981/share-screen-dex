import 'package:flutter/widgets.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SideScreenApp());
}

/// The native hosts launch this entrypoint on the external-display engine.
@pragma('vm:entry-point')
void externalDisplayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SideScreenApp(external: true));
}
