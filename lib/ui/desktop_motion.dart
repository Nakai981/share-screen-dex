import 'package:flutter/physics.dart';

/// macOS-inspired scale and spring motion, rendered locally by Flutter.
/// Critical damping avoids wobbling text/platform views during window changes.
abstract final class DesktopMotion {
  static final opening = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 360),
    bounce: 0,
  );
  static final closing = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 220),
    bounce: 0,
  );
  static final layout = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
    bounce: 0,
  );
}
