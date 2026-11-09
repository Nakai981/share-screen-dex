import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/app.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/platform/display_bridge.dart';
import 'package:side_screen/ui/controller_page.dart';
import 'package:side_screen/ui/hardware_controller_page.dart';

void main() {
  testWidgets(
    'presentation opens full controls once, reconnect reopens, unplug returns',
    (tester) async {
      final session = AppSession();
      const channel = MethodChannel(DisplayBridge.channelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'status': {'nativeAvailable': true},
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      addTearDown(session.dispose);
      await session.start();
      await tester.pumpWidget(
        MaterialApp(home: ControllerPage(session: session)),
      );
      await tester.pumpAndSettle();
      void status(bool presenting) => session.bridge.onStatus!(
        DisplayStatus(
          nativeAvailable: true,
          connected: true,
          presenting: presenting,
          name: 'Monitor',
        ),
      );
      status(false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fullscreen-remote-controller')),
        findsNothing,
      );
      status(true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fullscreen-remote-controller')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Điều khiển'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Về bảng điều khiển'));
      await tester.pumpAndSettle();
      status(true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fullscreen-remote-controller')),
        findsNothing,
      );
      status(false);
      status(true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fullscreen-remote-controller')),
        findsOneWidget,
      );
      status(false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fullscreen-remote-controller')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mouse hover moves pointer with no button, click is not duplicated',
    (tester) async {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareControllerPage(workspace: workspace, fullScreen: true),
        ),
      );
      await tester.pumpAndSettle();
      final pad = tester.getRect(find.byKey(const ValueKey('touchpad')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: pad.center);
      await mouse.moveTo(pad.center);
      final before = workspace.cursor;
      await mouse.moveTo(pad.center + const Offset(20, 10));
      expect(workspace.cursor - before, const Offset(70, 35));
      final serial = workspace.browserCommandSerial;
      await mouse.down(pad.center + const Offset(20, 10));
      await mouse.up();
      expect(workspace.browserCommandSerial, serial + 1);
      expect(workspace.browserCommand?['type'], 'click');
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'full controls keep IME and pointer area within $size with keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final workspace = WorkspaceController();
        addTearDown(workspace.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: HardwareControllerPage(
              workspace: workspace,
              fullScreen: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('remote-notes'));
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, true);
        await tester.tap(find.byKey(const ValueKey('remote-keyboard-toggle')));
        await tester.pumpAndSettle();
        final client = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        final config = (client.arguments as List)[1] as Map;
        expect((config['inputType'] as Map)['name'], 'TextInputType.multiline');
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 500 ? 220 : 300,
        );
        await tester.pumpAndSettle();
        const value = TextEditingValue(
          text: 'tiếng Việt',
          selection: TextSelection.collapsed(offset: 10),
          composing: TextRange(start: 6, end: 10),
        );
        tester.testTextInput.updateEditingValue(value);
        workspace.dispatch({'type': 'pointerMove', 'dx': 1, 'dy': 1});
        await tester.pump();
        expect(workspace.notes, value.text);
        expect(tester.widget<TextField>(field).controller!.value, value);
        expect(
          tester.getRect(find.byKey(const ValueKey('touchpad'))).height,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  test(
    'old dock inset resets, new custom inset survives, hover uses click coordinates',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      final old = workspace.snapshot()..remove('dockVersion');
      old['safeInset'] = 64;
      workspace.restore(old);
      expect(workspace.safeInset, 8);
      workspace.dispatch({'type': 'safeInset', 'value': 24});
      workspace.restore(workspace.snapshot());
      expect(workspace.safeInset, 24);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      final body = workspace.windows.last.visibleRect;
      final position = Offset(body.center.dx, body.top + 200);
      workspace.dispatch({
        'type': 'pointerMove',
        'dx': position.dx - workspace.cursor.dx,
        'dy': position.dy - workspace.cursor.dy,
      });
      final hover = workspace.browserPointerPosition!;
      workspace.dispatch({'type': 'click'});
      expect(workspace.browserCommand?['x'], closeTo(hover.dx, .0001));
      expect(workspace.browserCommand?['y'], closeTo(hover.dy, .0001));
      workspace.dispatch({'type': 'open', 'app': 'notes'});
      expect(workspace.browserPointerPosition, isNull);
    },
  );
}
