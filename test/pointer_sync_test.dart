import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/app.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/platform/display_bridge.dart';
import 'package:side_screen/ui/cute_cursor.dart';
import 'package:side_screen/ui/desktop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reopening an app retiles even after manual dragging enabled free layout',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({
        'type': 'moveWindow',
        'app': 'notes',
        'dx': -500,
        'dy': -100,
      });
      expect(workspace.autoTile, false);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      final visible = workspace.windows.where((w) => !w.minimized).toList();
      for (var i = 0; i < visible.length; i++) {
        for (final other in visible.skip(i + 1)) {
          expect(visible[i].visibleRect.overlaps(other.visibleRect), false);
        }
      }
      workspace.dispatch({'type': 'maximize', 'app': 'browser'});
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'https://example.com',
      });
      expect(
        workspace.windows.last.maximized,
        true,
        reason: 'Typing a URL must not undo an explicit maximize.',
      );
      workspace.restore({
        'schemaVersion': 1,
        'layoutVersion': 2,
        'autoTile': false,
        'windows': [
          for (final app in ['notes', 'browser'])
            {'app': app, 'x': 100, 'y': 100, 'width': 550, 'height': 474},
        ],
      });
      expect(workspace.autoTile, true);
      expect(
        workspace.windows.first.visibleRect.overlaps(
          workspace.windows.last.visibleRect,
        ),
        false,
      );
    },
  );

  test(
    'cursor patches notify only the pointer layer and keep scale across a reconnect',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      var sceneChanges = 0;
      var pointers = 0;
      workspace.sceneChanges.addListener(() => sceneChanges++);
      workspace.pointerChanges.addListener(() => pointers++);
      workspace.dispatch({'type': 'pointerMove', 'dx': 20, 'dy': -10});
      workspace.applyPointer({'cursorX': 500, 'cursorY': 300});
      expect(sceneChanges, 0);
      expect(pointers, 2);
      expect(workspace.cursor, const Offset(500, 300));
      workspace.dispatch({'type': 'cursorScale', 'value': .8});
      final copy = WorkspaceController();
      addTearDown(copy.dispose);
      copy.restore(workspace.snapshot());
      expect(copy.cursorScale, .8);
    },
  );

  testWidgets(
    'moving the cursor reuses window widgets and the new pointer is smaller',
    (tester) async {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopView(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      final notes = tester.widget(find.byKey(const ValueKey('desktop-notes')));
      for (var i = 0; i < 8; i++) {
        workspace.dispatch({'type': 'pointerMove', 'dx': 2, 'dy': 1});
        await tester.pump();
      }
      expect(
        identical(
          notes,
          tester.widget(find.byKey(const ValueKey('desktop-notes'))),
        ),
        true,
      );
      final cursor = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is CuteCursorPainter,
      );
      final logical = tester.widget<CustomPaint>(cursor).size;
      expect(logical.width, 16);
      expect(logical.height, 20);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native chrome capability suppresses duplicate Flutter taskbar and cursor',
    (tester) async {
      const channel = MethodChannel(DisplayBridge.channelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'initialize') {
          return {
            'status': {
              'nativeAvailable': true,
              'nativeChrome': true,
              'supportsPointerUpdates': true,
            },
          };
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(const SideScreenApp(external: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-taskbar')), findsNothing);
      expect(find.byKey(const ValueKey('desktop-cursor')), findsNothing);
      expect(find.byKey(const ValueKey('desktop-notes')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final incremental in [true, false]) {
    testWidgets(
      'pointer transport negotiates incremental=$incremental and coalesces movements',
      (tester) async {
        const channel = MethodChannel(DisplayBridge.channelName);
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'initialize') {
              return {
                'status': {
                  'nativeAvailable': true,
                  'supportsPointerUpdates': incremental,
                },
              };
            }
            calls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final session = AppSession();
        await session.start();
        await tester.pump(const Duration(milliseconds: 20));
        calls.clear();
        for (var i = 0; i < 20; i++) {
          session.workspace.dispatch({'type': 'pointerMove', 'dx': 1, 'dy': 1});
        }
        await tester.pump(const Duration(milliseconds: 20));
        final updates = calls
            .where((call) => call.method.startsWith('publish'))
            .toList();
        expect(updates.length, 1);
        expect(
          updates.single.method,
          incremental ? 'publishPointer' : 'publishState',
        );
        if (incremental) {
          expect((updates.single.arguments as Map).keys.toSet(), {
            'cursorX',
            'cursorY',
          });
        }
        session.workspace.dispatch({
          'type': 'notes',
          'text': 'Still synchronized',
        });
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          calls.lastWhere((call) => call.method.startsWith('publish')).method,
          'publishState',
        );
        session.dispose();
      },
    );
  }
}
