import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/app.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/ui/controller_page.dart';
import 'package:side_screen/ui/desktop.dart';
import 'package:side_screen/ui/desktop_viewport.dart';
import 'package:side_screen/ui/keyboard_preferences.dart';
import 'package:side_screen/ui/window_motion.dart';

void main() {
  test(
    'adaptive display keeps windows, dock hit testing and cursor inside each monitor',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      for (final size in [
        const Size(1920, 1080),
        const Size(2560, 1600),
        const Size(3440, 1440),
      ]) {
        workspace.dispatch({
          'type': 'displayViewport',
          'width': size.width,
          'height': size.height,
        });
        expect(
          workspace.canvasSize.aspectRatio,
          closeTo(size.aspectRatio, .001),
        );
        workspace.dispatch({'type': 'close', 'app': 'browser'});
        workspace.dispatch({'type': 'open', 'app': 'browser'});
        final window = workspace.windows.last;
        expect(window.visibleRect.right, workspace.canvasSize.width - 16);
        workspace.dispatch({'type': 'minimize', 'app': 'browser'});
        final dock = workspace.dockItem(1).center;
        workspace.dispatch({
          'type': 'pointerMove',
          'dx': dock.dx - workspace.cursor.dx,
          'dy': dock.dy - workspace.cursor.dy,
        });
        workspace.dispatch({'type': 'click'});
        expect(workspace.activeApp, DeskApp.browser);
        expect(workspace.windows.last.minimized, false);
        workspace.dispatch({'type': 'pointerMove', 'dx': 99999, 'dy': 99999});
        expect(workspace.cursor.dx, workspace.canvasSize.width - 1);
      }
      workspace.dispatch({'type': 'fullScreen', 'enabled': false});
      expect(workspace.canvasSize, desktopSize);
      workspace.dispatch({'type': 'fullScreen', 'enabled': true});
      final mirror = WorkspaceController();
      addTearDown(mirror.dispose);
      mirror.restore(workspace.snapshot());
      expect(mirror.canvasSize, workspace.canvasSize);
      expect(
        mirror.windows.last.visibleRect,
        workspace.windows.last.visibleRect,
      );
    },
  );

  for (final size in [
    const Size(1920, 1080),
    const Size(2560, 1600),
    const Size(3440, 1440),
    const Size(3840, 2160),
  ]) {
    testWidgets(
      'external workspace fills ${size.width} × ${size.height} without stretching or clipping',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final workspace = WorkspaceController();
        addTearDown(workspace.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DesktopViewport(workspace: workspace)),
          ),
        );
        await tester.pumpAndSettle();
        final wallpaper = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is WallpaperPainter,
        );
        expect(tester.getRect(wallpaper), Offset.zero & size);
        final dock = tester.getRect(
          find.byKey(const ValueKey('desktop-taskbar')),
        );
        expect(dock.width, closeTo(320, .01));
        expect(dock.height, closeTo(72, .01));
        expect(size.height - dock.bottom, closeTo(8, .01));
        expect(dock.center.dx, closeTo(size.width / 2, .01));
        final browser = find.byKey(const ValueKey('dock-browser'));
        final hitPoint = workspace.dockItem(1).center * (size.height / 900);
        expect(tester.getRect(browser).contains(hitPoint), true);
        await tester.tap(browser);
        await tester.pumpAndSettle();
        expect(workspace.activeApp, DeskApp.browser);
        expect(workspace.windows.last.maximized, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test(
    'renderer point dimensions override physical display metadata until disconnect',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({
        'type': 'displayViewport',
        'width': 1920,
        'height': 1080,
        'source': 'display',
      });
      workspace.dispatch({
        'type': 'displayViewport',
        'width': 1280,
        'height': 720,
        'source': 'renderer',
      });
      final rect = workspace.dockRect;
      workspace.dispatch({
        'type': 'displayViewport',
        'width': 3840,
        'height': 2160,
        'source': 'display',
      });
      expect(workspace.viewportHeight, 720);
      expect(workspace.dockRect, rect);
      workspace.forgetRendererViewport();
      workspace.dispatch({
        'type': 'displayViewport',
        'width': 3840,
        'height': 2160,
        'source': 'display',
      });
      expect(workspace.viewportHeight, 2160);
    },
  );

  test(
    'keyboard language persists and unchanged echoes preserve an IME composing range',
    () {
      final workspace = WorkspaceController();
      final copy = WorkspaceController();
      addTearDown(workspace.dispose);
      addTearDown(copy.dispose);
      workspace.dispatch({
        'type': 'keyboardLanguage',
        'language': 'vietnamese',
      });
      copy.restore(workspace.snapshot(forStorage: true));
      expect(copy.keyboardLanguage, KeyboardLanguage.vietnamese);
      expect(KeyboardLanguage.system.hintLocales, isNull);
      final controller = SyncedTextController(text: '');
      addTearDown(controller.dispose);
      const composing = TextEditingValue(
        text: 'tiế',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      controller.value = composing;
      controller.syncRemote('');
      controller.syncRemote('ti');
      expect(controller.value, composing);
      controller.syncRemote('tiế');
      expect(controller.value, composing);
      controller.value = const TextEditingValue(
        text: 'tiếng Việt',
        selection: TextSelection.collapsed(offset: 10),
      );
      controller.syncRemote('tiế');
      expect(controller.text, 'tiếng Việt');
      controller.syncRemote('tiếng Việt');
      expect(controller.text, 'tiếng Việt');
    },
  );

  testWidgets(
    'Vietnamese IME composition and language hints survive workspace notifications',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const SideScreenApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await tester.pumpAndSettle();
      final workspace = tester
          .widget<ControllerPage>(find.byType(ControllerPage))
          .session
          .workspace;
      workspace.dispatch({
        'type': 'keyboardLanguage',
        'language': 'vietnamese',
      });
      await tester.pump();
      final editor = find.byKey(const ValueKey('phone-notes'));
      await tester.showKeyboard(editor);
      const composing = TextEditingValue(
        text: 'Xin chào',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 4, end: 8),
      );
      tester.testTextInput.updateEditingValue(composing);
      workspace.dispatch({'type': 'pointerMove', 'dx': 1, 'dy': 1});
      await tester.pump();
      final field = tester.widget<TextField>(editor);
      expect(field.controller!.value, composing);
      expect(field.hintLocales, const [Locale('vi', 'VN')]);
      expect(workspace.notes, 'Xin chào');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'animation ticks reuse window contents instead of rebuilding the app',
    (tester) async {
      var builds = 0;
      final changes = ValueNotifier<DeskWindow?>(null);
      addTearDown(changes.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              ValueListenableBuilder<DeskWindow?>(
                valueListenable: changes,
                builder: (context, window, _) => DesktopWindowMotion(
                  app: DeskApp.notes,
                  window: window,
                  builder: (_) {
                    builds++;
                    return const ColoredBox(color: Colors.white);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      changes.value = DeskWindow(
        app: DeskApp.notes,
        rect: const Rect.fromLTWH(100, 100, 500, 400),
      );
      await tester.pump();
      final initial = builds;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds, initial);
      expect(initial, greaterThan(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
