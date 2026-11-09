import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/ui/desktop.dart';
import 'package:side_screen/ui/hardware_controller_page.dart';

void main() {
  test(
    'dock toggles foreground windows, activates background apps and opens closed apps',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({'type': 'notes', 'text': 'Giữ bản nháp'});
      workspace.dispatch({'type': 'maximize', 'app': 'notes'});
      final rect = workspace.windows.last.visibleRect;
      workspace.dispatch({'type': 'dockActivate', 'app': 'notes'});
      expect(workspace.activeApp, DeskApp.guide);
      expect(workspace.windows.last.minimized, true);
      workspace.dispatch({'type': 'dockActivate', 'app': 'notes'});
      expect(workspace.activeApp, DeskApp.notes);
      expect(workspace.windows.last.visibleRect, rect);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      workspace.dispatch({'type': 'dockActivate', 'app': 'notes'});
      expect(workspace.activeApp, DeskApp.notes);
      expect(workspace.windows.last.minimized, false);
      workspace.dispatch({'type': 'close', 'app': 'notes'});
      final restored = WorkspaceController()
        ..restore(workspace.snapshot(forStorage: true));
      addTearDown(restored.dispose);
      expect(restored.windows.any((w) => w.app == DeskApp.notes), false);
      restored.dispatch({'type': 'dockActivate', 'app': 'notes'});
      expect(restored.notes, 'Giữ bản nháp');
      expect(restored.windows.last.maximized, true);
    },
  );

  testWidgets(
    'physical dock taps and virtual clicks share minimize and restore behavior',
    (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dock-notes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-notes')), findsNothing);
      workspace.dispatch({
        'type': 'pointerMove',
        'dx': workspace.dockItem(0).center.dx - workspace.cursor.dx,
        'dy': workspace.dockItem(0).center.dy - workspace.cursor.dy,
      });
      workspace.dispatch({'type': 'click'});
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-notes')), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(workspace.windows.any((w) => w.app == DeskApp.notes), false);
      expect(
        find.byKey(const ValueKey('desktop-notes'), skipOffstage: false),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'external notes never own native input or create interceptor views',
    (tester) async {
      final actions = <Map<String, Object?>>[];
      final workspace = WorkspaceController(forwardAction: actions.add);
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('desktop-notes'));
      final notes = tester.widget<TextField>(field);
      expect(notes.readOnly, true);
      expect(notes.canRequestFocus, false);
      expect(notes.enableInteractiveSelection, false);
      expect(
        tester
            .widgetList<PointerInterceptor>(find.byType(PointerInterceptor))
            .every((w) => !w.intercepting),
        true,
      );
      await tester.tap(field);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('phone offers a direct close button without reopening notes', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    workspace.dispatch({'type': 'close', 'app': 'guide'});
    await tester.pumpWidget(
      MaterialApp(
        home: HardwareControllerPage(workspace: workspace, fullScreen: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-close-window')));
    await tester.pumpAndSettle();
    expect(workspace.activeApp, isNull);
    expect(workspace.windows, isEmpty);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('remote-close-window')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
