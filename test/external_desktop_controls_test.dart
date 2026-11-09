import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/ui/desktop.dart';
import 'package:side_screen/ui/desktop_viewport.dart';
import 'package:side_screen/ui/hardware_controller_page.dart';

void main() {
  late WorkspaceController workspace;
  setUp(() => workspace = WorkspaceController());
  tearDown(() => workspace.dispose());

  void expectSeparated() {
    final visible = workspace.windows.where((w) => !w.minimized).toList();
    for (var i = 0; i < visible.length; i++) {
      final r = visible[i].visibleRect;
      expect(r.left, greaterThanOrEqualTo(8));
      expect(r.right, lessThanOrEqualTo(workspace.canvasSize.width - 8));
      expect(r.bottom, lessThan(workspace.dockRect.top));
      for (final other in visible.skip(i + 1)) {
        expect(r.overlaps(other.visibleRect), false);
      }
    }
  }

  testWidgets(
    'expanded preview controls stay above the desktop instead of covering title bars',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: DesktopPreviewPage(workspace: workspace)),
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(
        find.byKey(const ValueKey('preview-fullscreen')),
      );
      final viewport = tester.getRect(find.byType(DesktopViewport));
      expect(button.bottom, lessThanOrEqualTo(viewport.top));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  test(
    'new apps and old layouts open maximized and arrange is an explicit action',
    () {
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      expect(workspace.windows.where((w) => !w.minimized).length, 3);
      expect(workspace.windows.every((w) => w.maximized), true);
      expect(workspace.autoTile, false);
      workspace.dispatch({'type': 'minimize', 'app': 'guide'});
      expect(workspace.windows.last.maximized, true);
      workspace.dispatch({'type': 'open', 'app': 'guide'});
      expect(workspace.windows.last.maximized, true);
      workspace.restore({
        'schemaVersion': 1,
        'notes': 'Giữ bản nháp',
        'windows': [
          for (final app in DeskApp.values)
            {'app': app.name, 'x': 100, 'y': 100, 'width': 550, 'height': 474},
        ],
      });
      expect(workspace.windows.every((w) => w.maximized), true);
      expect(workspace.notes, 'Giữ bản nháp');
      workspace.dispatch({'type': 'arrange'});
      expectSeparated();
    },
  );

  test(
    'floating windows overlap and focus, minimize and close preserve other geometry',
    () {
      expect(workspace.windows.every((w) => w.maximized), true);
      workspace.dispatch({'type': 'maximize', 'app': 'notes'});
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      workspace.dispatch({'type': 'maximize', 'app': 'browser'});
      final notes = workspace.windows.firstWhere((w) => w.app == DeskApp.notes);
      final browser = workspace.windows.last;
      final original = notes.rect;
      expect(browser.rect.overlaps(notes.rect), true);
      workspace.dispatch({'type': 'focus', 'app': 'notes'});
      expect(workspace.windows.last, same(notes));
      expect(browser.minimized, false);
      workspace.dispatch({'type': 'minimize', 'app': 'browser'});
      expect(notes.rect, original);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      expect(browser.maximized, false);
      expect(notes.rect, original);
      workspace.dispatch({'type': 'close', 'app': 'browser'});
      expect(notes.rect, original);
      expect(workspace.autoTile, false);
    },
  );

  test(
    'taskbar recovery raises it above cropped edges and survives a reconnect',
    () {
      workspace.dispatch({'type': 'recoverDesktop'});
      expect(workspace.canvasSize.height - workspace.dockRect.bottom, 64);
      workspace.dispatch({'type': 'safeInset', 'value': 96});
      workspace.dispatch({'type': 'maximize', 'app': 'notes'});
      expect(
        workspace.windows.last.visibleRect.bottom,
        lessThan(workspace.dockRect.top),
      );
      final mirror = WorkspaceController();
      addTearDown(mirror.dispose);
      mirror.restore(workspace.snapshot());
      expect(mirror.dockRect, workspace.dockRect);
      expect(
        mirror.windows.last.visibleRect,
        workspace.windows.last.visibleRect,
      );
      expect(mirror.safeInset, 96);
    },
  );

  test(
    'narrow displays keep overlapping apps available without automatic minimizing',
    () {
      workspace.dispatch({
        'type': 'displayViewport',
        'width': 600,
        'height': 900,
      });
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      expect(workspace.windows.every((w) => !w.minimized && w.maximized), true);
      expect(workspace.activeApp, DeskApp.browser);
      workspace.dispatch({'type': 'open', 'app': 'notes'});
      expect(workspace.activeApp, DeskApp.notes);
      expect(workspace.windows.length, 3);
      expect(workspace.windows.every((w) => !w.minimized && w.maximized), true);
    },
  );

  testWidgets(
    'taskbar stays visible and clickable while a window is maximized',
    (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byKey(const ValueKey('desktop-taskbar')));
      expect(bar.bottom, lessThanOrEqualTo(900 - desktopSafeInset));
      expect(bar.width, 320);
      expect(bar.height, 72);
      await tester.tap(find.byKey(const ValueKey('dock-browser')));
      await tester.pumpAndSettle();
      expect(workspace.activeApp, DeskApp.browser);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mouse hover, touch clicks and drag use the same coordinates on the external desktop',
    (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RemotePointerSurface(workspace: workspace)),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(workspace.dockItem(1).center);
      expect(workspace.cursor, workspace.dockItem(1).center);
      // AssistiveTouch may deliver touch events, so this must also work as a tap.
      await tester.tapAt(workspace.dockItem(1).center);
      await tester.pump();
      expect(workspace.activeApp, DeskApp.browser);
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(600, 400),
          scrollDelta: Offset(0, 120),
        ),
      );
      expect(workspace.browserCommand?['type'], 'scroll');
      expect(workspace.browserCommand?['dy'], 120);
      workspace.dispatch({'type': 'close', 'app': 'browser'});
      workspace.dispatch({'type': 'maximize', 'app': 'notes'});
      workspace.dispatch({
        'type': 'moveWindow',
        'app': 'notes',
        'dx': 0,
        'dy': 0,
      });
      final window = workspace.windows.last;
      final before = window.rect;
      await tester.dragFrom(
        before.topLeft + const Offset(40, 24),
        const Offset(10, 12),
      );
      await tester.pump();
      expect(window.rect.top, greaterThan(before.top));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Bluetooth-style keys launch apps, focus the address and close the active window',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HardwareControllerPage(workspace: workspace)),
      );
      await tester.pumpAndSettle();
      Future<void> chord(LogicalKeyboardKey key, {bool shift = false}) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(key);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await chord(LogicalKeyboardKey.digit2);
      expect(workspace.activeApp, DeskApp.browser);
      await chord(LogicalKeyboardKey.keyL);
      final address = tester.widget<TextField>(
        find.byKey(const ValueKey('browser-address-hardware')),
      );
      expect(address.focusNode!.hasFocus, true);
      await chord(LogicalKeyboardKey.keyW);
      expect(workspace.windows.any((w) => w.app == DeskApp.browser), false);
      await chord(LogicalKeyboardKey.digit1);
      final notes = find.byKey(const ValueKey('hardware-notes'));
      await tester.enterText(notes, 'Bàn phím Bluetooth · tiếng Việt');
      await tester.pump();
      expect(workspace.notes, 'Bàn phím Bluetooth · tiếng Việt');
      await chord(LogicalKeyboardKey.keyT, shift: true);
      expectSeparated();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
