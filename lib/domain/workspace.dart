import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const desktopSize = Size(1440, 900);
const desktopTop = 44.0;
const desktopBottom = 804.0;
const desktopDockRect = Rect.fromLTWH(552, 808, 336, 86);
const browserHome = 'sidescreen://home';
const browserDemo = 'sidescreen://demo';

Rect dockRectFor(Size size) =>
    Rect.fromLTWH((size.width - 336) / 2, 808, 336, 86);
Rect dockItemRect(int index, [Size size = desktopSize]) =>
    Rect.fromLTWH((size.width - 320) / 2 + index * 82, 816, 74, 70);
int dockIndex(DeskApp app) => switch (app) {
  DeskApp.notes => 0,
  DeskApp.browser => 1,
  DeskApp.guide => 2,
};

String normalizeBrowserAddress(String input) {
  final text = input.trim();
  if (text.isEmpty || text == browserHome) return browserHome;
  if (text == browserDemo) return browserDemo;
  if (text.length > 4096) throw const FormatException('Địa chỉ quá dài.');
  final explicit = Uri.tryParse(text);
  final hasScheme =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text) ||
      RegExp(
        r'^(javascript|data|file|about|vbscript):',
        caseSensitive: false,
      ).hasMatch(text);
  if (hasScheme) {
    if (explicit == null ||
        !['https', 'http'].contains(explicit.scheme) ||
        explicit.host.isEmpty) {
      throw const FormatException('Chỉ hỗ trợ địa chỉ http hoặc https.');
    }
    return explicit.toString();
  }
  if (!text.contains(RegExp(r'\s')) &&
      (text.contains('.') || text.startsWith('localhost'))) {
    final url = Uri.tryParse('https://$text');
    if (url != null && url.host.isNotEmpty) return url.toString();
  }
  return Uri.https('www.google.com', '/search', {'q': text}).toString();
}

enum DeskApp { notes, guide, browser }

enum KeyboardLanguage { system, vietnamese, english, japanese, korean, chinese }

class DeskWindow {
  DeskWindow({
    required this.app,
    required this.rect,
    this.minimized = false,
    this.maximized = false,
    this.canvasWidth = 1440,
  });
  final DeskApp app;
  Rect rect;
  bool minimized;
  bool maximized;
  double canvasWidth;
  Rect get visibleRect =>
      maximized ? Rect.fromLTWH(16, 56, canvasWidth - 32, 732) : rect;
  Map<String, Object?> toJson() => {
    'app': app.name,
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'minimized': minimized,
    'maximized': maximized,
  };
}

/// The phone is authoritative. External controllers forward actions and only
/// render snapshots, preventing divergent state between Flutter isolates.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({this.forwardAction});
  final void Function(Map<String, Object?> action)? forwardAction;
  final List<DeskWindow> _windows = [
    DeskWindow(
      app: DeskApp.guide,
      rect: const Rect.fromLTWH(100, 126, 590, 520),
    ),
    DeskWindow(
      app: DeskApp.notes,
      rect: const Rect.fromLTWH(750, 224, 550, 474),
    ),
  ];
  final Map<DeskApp, int> launches = {};
  final List<String> _browserHistory = [browserHome];
  int _browserIndex = 0;
  int browserReload = 0;
  int browserCommandSerial = 0;
  Map<String, Object?>? browserCommand;
  String? browserError;
  String get browserUrl => _browserHistory[_browserIndex];
  bool get browserCanGoBack => _browserIndex > 0;
  bool get browserCanGoForward => _browserIndex < _browserHistory.length - 1;
  String notes =
      'Ý tưởng lớn bắt đầu từ một ghi chú nhỏ.\n\nChạm vào Bàn phím trên điện thoại để viết ở đây.';
  Offset cursor = const Offset(714, 400);
  int wallpaper = 0;
  int revision = 0;
  bool fullScreen = true;
  double displayAspect = 1.6;
  KeyboardLanguage keyboardLanguage = KeyboardLanguage.system;
  Size get canvasSize => Size(fullScreen ? 900 * displayAspect : 1440, 900);
  Rect get dockRect => dockRectFor(canvasSize);
  Rect dockItem(int index) => dockItemRect(index, canvasSize);
  DeskApp? _dragging;
  bool _resizing = false;
  List<DeskWindow> get windows => List.unmodifiable(_windows);
  DeskApp? get activeApp => _windows.where((w) => !w.minimized).lastOrNull?.app;

  void dispatch(Map<String, Object?> action) {
    if (forwardAction case final forward?) {
      forward(action);
      return;
    }
    final type = action['type'];
    final app = _app(action['app']);
    var persistent = true;
    switch (type) {
      case 'displayViewport':
        final width = _number(action['width']);
        final height = _number(action['height']);
        if (width <= 0 || height <= 0) return;
        final aspect = (width / height).clamp(.6, 4.0);
        if ((aspect - displayAspect).abs() < .001) return;
        displayAspect = aspect;
        _fitWindows();
        persistent = false;
      case 'fullScreen':
        if (action['enabled'] is! bool) return;
        fullScreen = action['enabled'] == true;
        _fitWindows();
      case 'keyboardLanguage':
        final language = KeyboardLanguage.values
            .where((l) => l.name == action['language'])
            .firstOrNull;
        if (language == null) return;
        keyboardLanguage = language;
      case 'open':
        if (app == null) return;
        _open(app);
      case 'focus':
        if (app == null) return;
        _focus(app);
      case 'minimize':
        if (app == null) return;
        _find(app)?.minimized = true;
      case 'close':
        if (app == null) return;
        _windows.removeWhere((w) => w.app == app);
      case 'maximize':
        if (app == null) return;
        final w = _find(app);
        if (w != null) {
          w.maximized = !w.maximized;
          _focus(app);
        }
      case 'moveWindow':
        if (app == null) return;
        _move(app, Offset(_number(action['dx']), _number(action['dy'])));
      case 'resizeWindow':
        if (app == null) return;
        _resize(app, Offset(_number(action['dx']), _number(action['dy'])));
      case 'notes':
        final text = action['text'];
        if (text is! String) return;
        notes = text.substring(0, math.min(text.length, 50000));
      case 'wallpaper':
        wallpaper = (wallpaper + 1) % 3;
      case 'browserNavigate':
      case 'browserLocation':
        if (action['url'] is! String) return;
        try {
          final url = normalizeBrowserAddress(action['url'] as String);
          if (type == 'browserLocation' && action['replace'] == true) {
            _browserHistory[_browserIndex] = url;
          } else {
            _navigate(url);
          }
          browserError = null;
          if (type == 'browserNavigate') _open(DeskApp.browser, launch: false);
        } on FormatException catch (error) {
          browserError = error.message;
          persistent = false;
        }
      case 'browserBack':
        if (browserCanGoBack) _browserIndex--;
        browserError = null;
      case 'browserForward':
        if (browserCanGoForward) _browserIndex++;
        browserError = null;
      case 'browserHome':
        _navigate(browserHome);
        browserError = null;
      case 'browserReload':
        browserReload++;
        browserError = null;
      case 'browserScroll':
        _browserCommand('scroll', dy: _number(action['dy']));
        persistent = false;
      case 'browserText':
        if (action['text'] is! String) return;
        final value = action['text'] as String;
        _browserCommand(
          'text',
          text: value.substring(0, math.min(value.length, 10000)),
        );
        persistent = false;
      case 'pointerMove':
        final delta = Offset(_number(action['dx']), _number(action['dy']));
        final old = cursor;
        cursor = Offset(
          (cursor.dx + delta.dx).clamp(0, canvasSize.width - 1),
          (cursor.dy + delta.dy).clamp(0, 899),
        );
        if (_dragging case final dragging?) {
          if (_resizing) {
            _resize(dragging, cursor - old);
          } else {
            _move(dragging, cursor - old);
          }
        } else {
          persistent = false;
        }
      case 'pointerDown':
        _dragging = null;
        _resizing = false;
        final target = _hit(cursor);
        if (target != null) {
          _focus(target.app);
          final r = target.visibleRect;
          if (cursor.dy < r.top + 48 && cursor.dx < r.right - 138) {
            _dragging = target.app;
          } else if (!target.maximized &&
              cursor.dx >= r.right - 28 &&
              cursor.dy >= r.bottom - 28) {
            _dragging = target.app;
            _resizing = true;
          }
        }
        persistent = false;
      case 'pointerUp':
        _dragging = null;
        _resizing = false;
        persistent = false;
      case 'click':
        _click();
      case 'centerPointer':
        cursor = canvasSize.center(Offset.zero);
        persistent = false;
      case 'reset':
        _windows.clear();
        _open(DeskApp.guide);
        _open(DeskApp.notes);
        cursor = canvasSize.center(Offset.zero);
        _dragging = null;
      default:
        return;
    }
    if (persistent) revision++;
    notifyListeners();
  }

  void _open(DeskApp app, {bool launch = true}) {
    if (launch) launches[app] = (launches[app] ?? 0) + 1;
    final existing = _find(app);
    if (existing != null) {
      existing.minimized = false;
      _focus(app);
      return;
    }
    _windows.add(
      DeskWindow(
        app: app,
        rect: switch (app) {
          DeskApp.notes => const Rect.fromLTWH(750, 224, 550, 474),
          DeskApp.guide => const Rect.fromLTWH(100, 126, 590, 520),
          DeskApp.browser => const Rect.fromLTWH(210, 92, 1040, 674),
        },
      ),
    );
    _fitWindows();
  }

  void _fitWindows() {
    final width = canvasSize.width;
    for (final w in _windows) {
      w.canvasWidth = width;
      final windowWidth = w.rect.width.clamp(440.0, width - 16);
      w.rect = Rect.fromLTWH(
        w.rect.left.clamp(8, width - windowWidth - 8),
        w.rect.top,
        windowWidth,
        w.rect.height,
      );
    }
    cursor = Offset(cursor.dx.clamp(0, width - 1), cursor.dy.clamp(0, 899));
  }

  void _focus(DeskApp app) {
    final existing = _find(app);
    if (existing == null) return;
    _windows.remove(existing);
    _windows.add(existing);
  }

  DeskWindow? _find(DeskApp app) {
    for (final w in _windows) {
      if (w.app == app) return w;
    }
    return null;
  }

  DeskWindow? _hit(Offset point) {
    for (final w in _windows.reversed) {
      if (!w.minimized && w.visibleRect.contains(point)) return w;
    }
    return null;
  }

  void _move(DeskApp app, Offset delta) {
    final w = _find(app);
    if (w == null || w.maximized) return;
    w.rect = Rect.fromLTWH(
      (w.rect.left + delta.dx).clamp(8, canvasSize.width - w.rect.width - 8),
      (w.rect.top + delta.dy).clamp(
        desktopTop + 8,
        desktopBottom - w.rect.height,
      ),
      w.rect.width,
      w.rect.height,
    );
  }

  void _resize(DeskApp app, Offset delta) {
    final w = _find(app);
    if (w == null || w.maximized) return;
    w.rect = Rect.fromLTWH(
      w.rect.left,
      w.rect.top,
      (w.rect.width + delta.dx).clamp(440, canvasSize.width - 8 - w.rect.left),
      (w.rect.height + delta.dy).clamp(340, desktopBottom - w.rect.top),
    );
  }

  void _click() {
    // Coordinates match the virtual desktop, including the dock and controls.
    if (dockRect.contains(cursor)) {
      for (final app in DeskApp.values) {
        if (dockItem(dockIndex(app)).contains(cursor)) _open(app);
      }
      if (dockItem(3).contains(cursor)) wallpaper = (wallpaper + 1) % 3;
      return;
    }
    final target = _hit(cursor);
    if (target == null) return;
    _focus(target.app);
    final r = target.visibleRect;
    if (cursor.dy < r.top + 48 && cursor.dx > r.right - 138) {
      final fromRight = r.right - cursor.dx;
      if (fromRight < 46) {
        _windows.remove(target);
      } else if (fromRight < 92) {
        target.maximized = !target.maximized;
      } else {
        target.minimized = true;
      }
    } else if (target.app == DeskApp.browser) {
      final local = cursor - r.topLeft;
      if (local.dy >= 48 && local.dy < 108) {
        if (local.dx >= 8 && local.dx < 48 && browserCanGoBack) _browserIndex--;
        if (local.dx >= 48 && local.dx < 88 && browserCanGoForward) {
          _browserIndex++;
        }
        if (local.dx >= 88 && local.dx < 128) browserReload++;
        if (local.dx >= 128 && local.dx < 168) _navigate(browserHome);
      } else if (local.dy >= 109 && local.dy < r.height - 33) {
        _browserCommand(
          'click',
          x: ((local.dx - 1) / (r.width - 2)).clamp(0, 1),
          y: ((local.dy - 109) / (r.height - 142)).clamp(0, 1),
        );
      }
    }
  }

  void _navigate(String url) {
    if (url == browserUrl) return;
    _browserHistory.removeRange(_browserIndex + 1, _browserHistory.length);
    _browserHistory.add(url);
    if (_browserHistory.length > 50) _browserHistory.removeAt(0);
    _browserIndex = _browserHistory.length - 1;
  }

  void _browserCommand(
    String type, {
    double x = .5,
    double y = .5,
    double dy = 0,
    String? text,
  }) {
    browserCommandSerial++;
    browserCommand = {
      'serial': browserCommandSerial,
      'type': type,
      'x': x,
      'y': y,
      'dy': dy,
      'text': ?text,
    };
  }

  Map<String, Object?> snapshot({bool forStorage = false}) => {
    'schemaVersion': 1,
    'notes': notes,
    'fullScreen': fullScreen,
    'displayAspect': displayAspect,
    'keyboardLanguage': keyboardLanguage.name,
    'wallpaper': wallpaper,
    'cursorX': cursor.dx,
    'cursorY': cursor.dy,
    'windows': _windows.map((w) => w.toJson()).toList(),
    'launches': {
      for (final app in DeskApp.values) app.name: launches[app] ?? 0,
    },
    'browserHistory': List<String>.of(_browserHistory),
    'browserIndex': _browserIndex,
    'browserReload': browserReload,
    'browserCommand': forStorage ? null : browserCommand,
    'browserError': browserError,
  };

  bool restore(Map<Object?, Object?> json) {
    if (json['schemaVersion'] != 1 || json['windows'] is! List) return false;
    fullScreen = json['fullScreen'] != false;
    displayAspect = _number(json['displayAspect'], 1.6).clamp(.6, 4.0);
    keyboardLanguage =
        KeyboardLanguage.values
            .where((l) => l.name == json['keyboardLanguage'])
            .firstOrNull ??
        KeyboardLanguage.system;
    final restored = <DeskWindow>[];
    for (final raw in (json['windows'] as List).take(DeskApp.values.length)) {
      if (raw is! Map) continue;
      final app = _app(raw['app']);
      if (app == null || restored.any((w) => w.app == app)) continue;
      final width = _number(
        raw['width'],
        550,
      ).clamp(440.0, canvasSize.width - 16);
      final height = _number(raw['height'], 474).clamp(340.0, 744.0);
      restored.add(
        DeskWindow(
          app: app,
          rect: Rect.fromLTWH(
            _number(raw['x'], 100).clamp(8, canvasSize.width - width - 8),
            _number(
              raw['y'],
              100,
            ).clamp(desktopTop + 8, desktopBottom - height),
            width,
            height,
          ),
          minimized: raw['minimized'] == true,
          maximized: raw['maximized'] == true,
          canvasWidth: canvasSize.width,
        ),
      );
    }
    _windows
      ..clear()
      ..addAll(restored);
    if (json['notes'] case final String text) {
      notes = text.substring(0, math.min(text.length, 50000));
    }
    wallpaper = _number(json['wallpaper']).toInt().clamp(0, 2);
    cursor = Offset(
      _number(json['cursorX'], 714).clamp(0, canvasSize.width - 1),
      _number(json['cursorY'], 400).clamp(0, 899),
    );
    _dragging = null;
    _resizing = false;
    if (json['launches'] case final Map rawLaunches) {
      for (final app in DeskApp.values) {
        launches[app] = _number(
          rawLaunches[app.name],
        ).toInt().clamp(0, 1000000000);
      }
    }
    _browserHistory.clear();
    if (json['browserHistory'] case final List rawHistory) {
      for (final raw in rawHistory.take(50)) {
        if (raw is! String) continue;
        try {
          _browserHistory.add(normalizeBrowserAddress(raw));
        } on FormatException {
          continue;
        }
      }
    }
    if (_browserHistory.isEmpty) _browserHistory.add(browserHome);
    _browserIndex = _number(
      json['browserIndex'],
    ).toInt().clamp(0, _browserHistory.length - 1);
    browserReload = _number(json['browserReload']).toInt();
    browserError = json['browserError'] is String
        ? json['browserError'] as String
        : null;
    browserCommand = json['browserCommand'] is Map
        ? Map<String, Object?>.from(json['browserCommand'] as Map)
        : null;
    browserCommandSerial = _number(browserCommand?['serial']).toInt();
    revision++;
    notifyListeners();
    return true;
  }

  static DeskApp? _app(Object? value) {
    for (final app in DeskApp.values) {
      if (app.name == value) return app;
    }
    return null;
  }

  static double _number(Object? value, [double fallback = 0]) =>
      value is num && value.isFinite ? value.toDouble() : fallback;
}
