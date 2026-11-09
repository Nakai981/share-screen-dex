import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';

void main() {
  late WorkspaceController desk;
  setUp(() {
    desk = WorkspaceController();
    // These movement tests deliberately use restored, floating windows.
    for (final app in [DeskApp.guide, DeskApp.notes]) {
      desk.dispatch({'type': 'maximize', 'app': app.name});
    }
  });
  tearDown(() => desk.dispose());

  test('window movement and resizing keep controls within desktop bounds', () {
    desk.dispatch({
      'type': 'moveWindow',
      'app': 'notes',
      'dx': -99999,
      'dy': -99999,
    });
    var notes = desk.windows.last;
    expect(notes.rect.topLeft, const Offset(8, 36));
    desk.dispatch({
      'type': 'resizeWindow',
      'app': 'notes',
      'dx': 99999,
      'dy': 99999,
    });
    expect(notes.rect.right, 1432);
    expect(notes.rect.bottom, desktopBottom);
    desk.dispatch({
      'type': 'resizeWindow',
      'app': 'notes',
      'dx': -99999,
      'dy': -99999,
    });
    expect(notes.rect.size, const Size(440, 340));
    desk.dispatch({'type': 'maximize', 'app': 'notes'});
    final before = notes.visibleRect;
    desk.dispatch({'type': 'moveWindow', 'app': 'notes', 'dx': 50, 'dy': 50});
    expect(notes.visibleRect, before);
  });

  test(
    'closing, minimizing, reopening and resetting preserve note content',
    () {
      desk.dispatch({
        'type': 'notes',
        'text': 'Xin chào 👋\nMột màn hình mới.',
      });
      desk.dispatch({'type': 'minimize', 'app': 'notes'});
      expect(desk.activeApp, DeskApp.guide);
      desk.dispatch({'type': 'open', 'app': 'notes'});
      expect(desk.windows.last.minimized, false);
      desk.dispatch({'type': 'close', 'app': 'notes'});
      expect(desk.windows.length, 1);
      desk.dispatch({'type': 'open', 'app': 'notes'});
      desk.dispatch({'type': 'reset'});
      expect(desk.notes, 'Xin chào 👋\nMột màn hình mới.');
      expect(desk.windows.length, 2);
    },
  );

  test('touchpad drags a title bar and releases capture', () {
    desk.dispatch({
      'type': 'pointerMove',
      'dx': 100 - desk.cursor.dx,
      'dy': 145 - desk.cursor.dy,
    });
    desk.dispatch({'type': 'pointerDown'});
    desk.dispatch({'type': 'pointerMove', 'dx': 120, 'dy': 60});
    expect(desk.windows.last.app, DeskApp.guide);
    expect(desk.windows.last.rect.topLeft, const Offset(220, 186));
    desk.dispatch({'type': 'pointerUp'});
    desk.dispatch({'type': 'pointerMove', 'dx': 20, 'dy': 20});
    expect(desk.windows.last.rect.topLeft, const Offset(220, 186));
  });

  test('touchpad resizes a window from its bottom-right grip', () {
    desk.dispatch({
      'type': 'pointerMove',
      'dx': 1290 - desk.cursor.dx,
      'dy': 688 - desk.cursor.dy,
    });
    desk.dispatch({'type': 'pointerDown'});
    desk.dispatch({'type': 'pointerMove', 'dx': 50, 'dy': 40});
    expect(desk.windows.last.rect.size, const Size(600, 514));
  });

  test(
    'touchpad hits window controls and dock using matching virtual coordinates',
    () {
      desk.dispatch({
        'type': 'pointerMove',
        'dx': 1280 - desk.cursor.dx,
        'dy': 240 - desk.cursor.dy,
      });
      desk.dispatch({'type': 'click'});
      expect(desk.windows.any((w) => w.app == DeskApp.notes), false);
      desk.dispatch({
        'type': 'pointerMove',
        'dx': 630 - desk.cursor.dx,
        'dy': 850 - desk.cursor.dy,
      });
      desk.dispatch({'type': 'click'});
      expect(desk.activeApp, DeskApp.notes);
    },
  );

  test(
    'a snapshot restores the workspace after an external engine reconnect',
    () {
      desk.dispatch({'type': 'notes', 'text': 'Nội dung được giữ lại'});
      desk.dispatch({'type': 'wallpaper'});
      desk.dispatch({'type': 'minimize', 'app': 'guide'});
      desk.dispatch({'type': 'maximize', 'app': 'notes'});
      final mirror = WorkspaceController();
      addTearDown(mirror.dispose);
      expect(mirror.restore(desk.snapshot()), true);
      expect(mirror.snapshot(), desk.snapshot());
    },
  );

  test(
    'invalid persisted geometry is normalized and unknown versions are ignored',
    () {
      final initial = desk.snapshot();
      expect(desk.restore({'schemaVersion': 90, 'windows': []}), false);
      expect(desk.snapshot(), initial);
      expect(
        desk.restore({
          'schemaVersion': 1,
          'cursorX': double.nan,
          'windows': [
            {
              'app': 'notes',
              'x': double.infinity,
              'y': -999,
              'width': 99999,
              'height': -90,
            },
            {'app': 'notes'},
          ],
        }),
        true,
      );
      expect(desk.windows.length, 1);
      expect(
        desk.windows.first.rect.width,
        lessThanOrEqualTo(desk.canvasSize.width - 16),
      );
      expect(desk.windows.first.rect.height, greaterThanOrEqualTo(340));
      expect(
        desk.windows.first.rect.bottom,
        lessThanOrEqualTo(desk.workBottom),
      );
      expect(desk.cursor.dx.isFinite, true);
    },
  );

  test(
    'external engines forward edits and await the authoritative snapshot',
    () {
      final actions = <Map<String, Object?>>[];
      final mirror = WorkspaceController(forwardAction: actions.add);
      addTearDown(mirror.dispose);
      final initialNotes = mirror.notes;
      mirror.dispatch({'type': 'notes', 'text': 'From second engine'});
      expect(mirror.notes, initialNotes);
      expect(actions.single['text'], 'From second engine');
      desk.dispatch(actions.single);
      mirror.restore(desk.snapshot());
      expect(mirror.notes, 'From second engine');
    },
  );

  test('pointer movement alone does not trigger persistence revisions', () {
    final revision = desk.revision;
    desk.dispatch({'type': 'pointerMove', 'dx': 20, 'dy': 20});
    expect(desk.revision, revision);
    desk.dispatch({'type': 'notes', 'text': 'Save this'});
    expect(desk.revision, revision + 1);
  });
}
