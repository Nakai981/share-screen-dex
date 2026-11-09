import 'package:flutter/services.dart';

class DisplayStatus {
  const DisplayStatus({
    this.nativeAvailable = false,
    this.connected = false,
    this.presenting = false,
    this.nativeChrome = false,
    this.supportsPointerUpdates = false,
    this.name,
    this.width,
    this.height,
    this.error,
  });
  factory DisplayStatus.fromMap(Map<Object?, Object?> value) => DisplayStatus(
    nativeAvailable: value['nativeAvailable'] == true,
    connected: value['connected'] == true,
    presenting: value['presenting'] == true,
    nativeChrome: value['nativeChrome'] == true,
    supportsPointerUpdates: value['supportsPointerUpdates'] == true,
    name: value['name'] as String?,
    width: (value['width'] as num?)?.toInt(),
    height: (value['height'] as num?)?.toInt(),
    error: value['error'] as String?,
  );
  final bool nativeAvailable;
  final bool connected;
  final bool presenting;
  final bool nativeChrome;
  final bool supportsPointerUpdates;
  final String? name;
  final int? width;
  final int? height;
  final String? error;
}

class DisplayBridge {
  static const channelName = 'dev.sidescreen/display';
  final MethodChannel _channel = const MethodChannel(channelName);
  void Function(DisplayStatus)? onStatus;
  void Function(Map<Object?, Object?>)? onSnapshot;
  void Function(Map<Object?, Object?>)? onPointer;
  void Function(Map<String, Object?>)? onAction;
  bool _available = false;
  Future<Map<Object?, Object?>?> initialize() async {
    _channel.setMethodCallHandler((call) async {
      final raw = call.arguments;
      if (raw is! Map) return;
      switch (call.method) {
        case 'displayChanged':
          onStatus?.call(DisplayStatus.fromMap(raw));
        case 'stateChanged':
          onSnapshot?.call(raw);
        case 'pointerChanged':
          onPointer?.call(raw);
        case 'action':
          onAction?.call(Map<String, Object?>.from(raw));
      }
    });
    try {
      final bootstrap = await _channel.invokeMapMethod<Object?, Object?>(
        'initialize',
      );
      _available = true;
      if (bootstrap?['status'] case final Map status) {
        onStatus?.call(DisplayStatus.fromMap(status));
      }
      return bootstrap?['state'] is Map ? bootstrap!['state'] as Map : null;
    } on MissingPluginException {
      onStatus?.call(const DisplayStatus());
    } on PlatformException catch (error) {
      onStatus?.call(DisplayStatus(error: error.message));
    }
    return null;
  }

  Future<void> publish(Map<String, Object?> state) =>
      _invoke('publishState', state);
  Future<void> publishPointer(Map<String, Object?> pointer) =>
      _invoke('publishPointer', pointer);
  Future<void> save(Map<String, Object?> state) => _invoke('saveState', state);
  Future<void> sendAction(Map<String, Object?> action) =>
      _invoke('dispatchAction', action);
  Future<void> refresh() => _invoke('refresh', null);
  Future<void> _invoke(String method, Object? arguments) async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      onStatus?.call(
        DisplayStatus(nativeAvailable: true, error: error.message),
      );
    } on MissingPluginException {
      _available = false;
      onStatus?.call(const DisplayStatus());
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    onStatus = null;
    onSnapshot = null;
    onPointer = null;
    onAction = null;
  }
}
