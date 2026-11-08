import 'dart:async';

import 'package:flutter/material.dart';

import 'domain/workspace.dart';
import 'platform/display_bridge.dart';
import 'ui/controller_page.dart';
import 'ui/desktop_viewport.dart';
import 'ui/theme.dart';

class AppSession extends ChangeNotifier with WidgetsBindingObserver {
  AppSession({this.external = false, DisplayBridge? bridge})
    : bridge = bridge ?? DisplayBridge() {
    workspace = WorkspaceController(
      forwardAction: external
          ? (action) => unawaited(this.bridge.sendAction(action))
          : null,
    );
  }
  final bool external;
  final DisplayBridge bridge;
  late final WorkspaceController workspace;
  DisplayStatus status = const DisplayStatus();
  bool ready = false;
  bool _disposed = false;
  int _savedRevision = -1;
  Timer? _publishTimer;
  Timer? _saveTimer;
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    bridge.onStatus = (value) {
      if (!_disposed) {
        status = value;
        if (!external &&
            value.presenting &&
            value.width != null &&
            value.height != null) {
          workspace.dispatch({
            'type': 'displayViewport',
            'width': value.width,
            'height': value.height,
          });
        }
        notifyListeners();
      }
    };
    bridge.onSnapshot = (state) {
      if (!_disposed && external) workspace.restore(state);
    };
    bridge.onAction = (action) {
      if (!_disposed && !external) workspace.dispatch(action);
    };
    final initial = await bridge.initialize();
    if (_disposed) return;
    if (initial != null) workspace.restore(initial);
    if (!external &&
        status.presenting &&
        status.width != null &&
        status.height != null) {
      workspace.dispatch({
        'type': 'displayViewport',
        'width': status.width,
        'height': status.height,
      });
    }
    if (!external) {
      workspace.addListener(_workspaceChanged);
      _workspaceChanged();
    }
    ready = true;
    notifyListeners();
  }

  void _workspaceChanged() {
    _publishTimer ??= Timer(const Duration(milliseconds: 16), () {
      _publishTimer = null;
      unawaited(bridge.publish(workspace.snapshot()));
    });
    if (_savedRevision != workspace.revision) {
      _savedRevision = workspace.revision;
      _saveTimer?.cancel();
      _saveTimer = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(bridge.save(workspace.snapshot(forStorage: true))),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (external) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(bridge.refresh());
      unawaited(bridge.publish(workspace.snapshot()));
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      workspace.dispatch({'type': 'pointerUp'});
      unawaited(bridge.save(workspace.snapshot(forStorage: true)));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _publishTimer?.cancel();
    _saveTimer?.cancel();
    workspace.removeListener(_workspaceChanged);
    bridge.dispose();
    workspace.dispose();
    super.dispose();
  }
}

class SideScreenApp extends StatefulWidget {
  const SideScreenApp({super.key, this.external = false});
  final bool external;
  @override
  State<SideScreenApp> createState() => _SideScreenAppState();
}

class _SideScreenAppState extends State<SideScreenApp> {
  late final AppSession session = AppSession(external: widget.external);
  @override
  void initState() {
    super.initState();
    unawaited(session.start());
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SideScreen',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: widget.external
        ? MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: Scaffold(
              body: DesktopViewport(workspace: session.workspace),
            ),
          )
        : ControllerPage(session: session),
  );
}
