import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/ui/desktop.dart';
import 'package:side_screen/ui/theme.dart';

void main() {
  late WorkspaceController workspace;
  setUp(() => workspace = WorkspaceController());
  tearDown(() => workspace.dispose());

  Future<void> mount(WidgetTester tester, {bool reduced = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = desktopSize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: desktopSize, disableAnimations: reduced),
          child: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'close keeps the outgoing window until fade completes, then opening animates from the dock',
    (tester) async {
      await mount(tester);
      workspace.dispatch({'type': 'close', 'app': 'notes'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final fade = tester.widget<Opacity>(
        find.byKey(const ValueKey('window-opacity-notes')),
      );
      expect(fade.opacity, greaterThan(0));
      expect(fade.opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-notes')), findsNothing);
      workspace.dispatch({'type': 'open', 'app': 'notes'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('window-opacity-notes')))
            .opacity,
        lessThan(1),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-notes')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'maximize animates geometry while a direct drag stays immediate',
    (tester) async {
      workspace.dispatch({'type': 'maximize', 'app': 'notes'});
      await mount(tester);
      final surface = find.byKey(const ValueKey('window-opacity-notes'));
      final initial = tester.getRect(surface);
      workspace.dispatch({'type': 'maximize', 'app': 'notes'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final during = tester.getRect(surface);
      expect(during.width, greaterThan(initial.width));
      expect(during.width, lessThan(1408));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface).width, 1408);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dock magnifies on actual mouse hover and on the phone virtual cursor',
    (tester) async {
      await mount(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(dockItemRect(1).center);
      await tester.pumpAndSettle();
      final icon = find.byKey(const ValueKey('dock-scale-Trình duyệt'));
      expect(
        tester.widget<Transform>(icon).transform.entry(0, 0),
        greaterThan(1.15),
      );
      await mouse.moveTo(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(tester.widget<Transform>(icon).transform.entry(0, 0), 1);
      final center = dockItemRect(1).center;
      workspace.dispatch({
        'type': 'pointerMove',
        'dx': center.dx - workspace.cursor.dx,
        'dy': center.dy - workspace.cursor.dy,
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<Transform>(icon).transform.entry(0, 0),
        greaterThan(1.15),
      );
      await mouse.removePointer();
    },
  );

  testWidgets('minimizing preserves an unfinished browser address', (
    tester,
  ) async {
    await mount(tester);
    workspace.dispatch({'type': 'open', 'app': 'browser'});
    await tester.pumpAndSettle();
    final address = find.byKey(const ValueKey('browser-address-desktop'));
    await tester.enterText(address, 'an-unfinished-address.example');
    workspace.dispatch({'type': 'minimize', 'app': 'browser'});
    await tester.pumpAndSettle();
    expect(address, findsNothing);
    workspace.dispatch({'type': 'open', 'app': 'browser'});
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(address).controller!.text,
      'an-unfinished-address.example',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion preference makes close immediate', (
    tester,
  ) async {
    await mount(tester, reduced: true);
    workspace.dispatch({'type': 'close', 'app': 'notes'});
    await tester.pump();
    expect(find.byKey(const ValueKey('desktop-notes')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
