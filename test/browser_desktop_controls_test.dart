import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/ui/desktop.dart';
import 'package:side_screen/ui/hardware_controller_page.dart';

void clickAt(WorkspaceController workspace, Offset position) {
  workspace.dispatch({
    'type': 'pointerMove',
    'dx': position.dx - workspace.cursor.dx,
    'dy': position.dy - workspace.cursor.dy,
  });
  workspace.dispatch({'type': 'click'});
}

void main() {
  testWidgets(
    'covered notes stay mounted but offstage, then return with their draft',
    (tester) async {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      workspace.dispatch({'type': 'notes', 'text': 'Không mất bản nháp'});
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-notes')), findsNothing);
      expect(
        find.byKey(const ValueKey('desktop-notes'), skipOffstage: false),
        findsOneWidget,
      );
      workspace.dispatch({'type': 'open', 'app': 'notes'});
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('browser-address-desktop')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('desktop-notes')))
            .controller!
            .text,
        'Không mất bản nháp',
      );
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      workspace.dispatch({'type': 'maximize', 'app': 'browser'});
      await tester.pumpAndSettle();
      expect(workspace.isWindowOccluded(DeskApp.notes), false);
      expect(find.byKey(const ValueKey('desktop-notes')), findsOneWidget);
      final clip = tester.widget<ClipPath>(
        find.byKey(const ValueKey('window-clip-notes')),
      );
      final back = workspace.windows
          .firstWhere((w) => w.app == DeskApp.notes)
          .visibleRect;
      final front = workspace.windows.last.visibleRect;
      final path = clip.clipper!.getClip(back.size);
      expect(path.contains(front.center - back.topLeft), false);
      expect(path.contains(const Offset(10, 10)), true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'compact toolbar button matches virtual mouse hit region and remains clickable',
    (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      final rect = workspace.windows.last.visibleRect;
      final exit = find.byKey(const ValueKey('browser-exit-video'));
      expect(tester.getRect(exit), browserExitRect(rect));
      expect(
        tester.getRect(find.byKey(const ValueKey('browser-toolbar'))).height,
        44,
      );
      expect(rect.top, 36);
      clickAt(workspace, browserExitRect(rect).center);
      expect(workspace.browserCommand?['type'], 'exitFullscreen');
      final serial = workspace.browserCommandSerial;
      await tester.tap(exit);
      await tester.pump();
      expect(workspace.browserCommandSerial, serial + 1);
      expect(
        tester.getRect(find.byKey(const ValueKey('browser-viewport'))),
        browserViewportRect(rect),
      );
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'javascript:blocked()',
      });
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('browser-viewport'))),
        browserViewportRect(rect, navigationError: true),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'virtual address click focuses phone input and mirrors editable draft and caret',
    (tester) async {
      final primary = WorkspaceController();
      final actions = <Map<String, Object?>>[];
      final mirror = WorkspaceController(forwardAction: actions.add);
      addTearDown(primary.dispose);
      addTearDown(mirror.dispose);
      primary.dispatch({'type': 'open', 'app': 'browser'});
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareControllerPage(workspace: primary, fullScreen: true),
        ),
      );
      await tester.pumpAndSettle();
      clickAt(
        primary,
        browserAddressRect(primary.windows.last.visibleRect).center,
      );
      await tester.pumpAndSettle();
      final phone = find.byKey(const ValueKey('browser-address-remote'));
      expect(tester.widget<TextField>(phone).focusNode!.hasFocus, true);
      await tester.enterText(phone, 'youtube.com');
      await tester.pump();
      expect(primary.browserAddressDraft, 'youtube.com');
      expect(primary.browserAddressCaret, 11);
      mirror.restore(primary.snapshot());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: mirror)),
        ),
      );
      await tester.pumpAndSettle();
      final desktop = tester.widget<TextField>(
        find.byKey(const ValueKey('browser-address-desktop')),
      );
      expect(desktop.readOnly, true);
      expect(tester.testTextInput.hasAnyClients, false);
      expect(desktop.showCursor, true);
      expect(desktop.focusNode!.hasFocus, true);
      expect(desktop.controller!.selection.extentOffset, 11);
      expect(desktop.controller!.text, 'youtube.com');
      clickAt(
        primary,
        Offset(
          browserAddressRect(primary.windows.last.visibleRect).right - 15,
          browserAddressRect(primary.windows.last.visibleRect).center.dy,
        ),
      );
      expect(primary.browserUrl, 'https://youtube.com');
      expect(primary.browserAddressEditing, false);
      expect(
        primary.snapshot(forStorage: true)['browserAddressEditing'],
        false,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
