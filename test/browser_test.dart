import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';

void main() {
  test(
    'redirect replaces the current history entry instead of trapping the back button',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'http://example.com',
      });
      workspace.dispatch({
        'type': 'browserLocation',
        'url': 'https://example.com/',
        'replace': true,
      });
      workspace.dispatch({'type': 'browserBack'});
      expect(workspace.browserUrl, browserHome);
      workspace.dispatch({'type': 'browserForward'});
      expect(workspace.browserUrl, 'https://example.com/');
    },
  );
  test('page input is relayed live but is excluded from disk snapshots', () {
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    final revision = workspace.revision;
    workspace.dispatch({
      'type': 'browserText',
      'text': 'Nội dung gửi vào trang',
    });
    expect(workspace.snapshot()['browserCommand'], isNotNull);
    expect(workspace.snapshot(forStorage: true)['browserCommand'], isNull);
    expect(workspace.revision, revision);
  });
  test(
    'address bar accepts web URLs, domains and searches, but rejects executable schemes',
    () {
      expect(normalizeBrowserAddress(' example.com '), 'https://example.com');
      final search = Uri.parse(normalizeBrowserAddress('bộ gõ tiếng Việt'));
      expect(search.host, 'www.google.com');
      expect(search.path, '/search');
      expect(search.queryParameters['q'], 'bộ gõ tiếng Việt');
      expect(normalizeBrowserAddress('google.com'), 'https://google.com');
      expect(
        normalizeBrowserAddress('http://localhost:8765/test'),
        'http://localhost:8765/test',
      );
      expect(
        Uri.parse(
          normalizeBrowserAddress('flutter animation'),
        ).queryParameters['q'],
        'flutter animation',
      );
      for (final value in [
        'javascript:alert(1)',
        'data:text/html,hello',
        'file:///etc/passwd',
        'ftp://example.com',
      ]) {
        expect(() => normalizeBrowserAddress(value), throwsFormatException);
      }
    },
  );

  test(
    'browser history truncates the forward branch and survives reconnect',
    () {
      final workspace = WorkspaceController();
      final mirror = WorkspaceController();
      addTearDown(workspace.dispose);
      addTearDown(mirror.dispose);
      workspace.dispatch({'type': 'browserNavigate', 'url': 'example.com'});
      workspace.dispatch({'type': 'browserNavigate', 'url': browserDemo});
      workspace.dispatch({'type': 'browserBack'});
      expect(workspace.browserUrl, 'https://example.com');
      expect(workspace.browserCanGoForward, true);
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'https://flutter.dev',
      });
      expect(workspace.browserCanGoForward, false);
      workspace.dispatch({'type': 'browserReload'});
      expect(mirror.restore(workspace.snapshot()), true);
      expect(mirror.snapshot(), workspace.snapshot());
      expect(mirror.windows.last.app, DeskApp.browser);
    },
  );

  test('old two-app snapshots migrate to the three-app desktop', () {
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    expect(
      workspace.restore({
        'schemaVersion': 1,
        'notes': 'Giữ lại',
        'windows': [
          {'app': 'notes', 'x': 100, 'y': 100, 'width': 550, 'height': 474},
        ],
      }),
      true,
    );
    expect(workspace.notes, 'Giữ lại');
    expect(workspace.browserUrl, browserHome);
    workspace.dispatch({'type': 'open', 'app': 'browser'});
    final copy = WorkspaceController();
    addTearDown(copy.dispose);
    expect(copy.restore(workspace.snapshot()), true);
    expect(copy.windows.length, 2);
    expect(copy.activeApp, DeskApp.browser);
  });

  test(
    'browser navigation does not steal focus when a background page redirects',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      workspace.dispatch({'type': 'open', 'app': 'notes'});
      workspace.dispatch({
        'type': 'browserLocation',
        'url': 'https://example.com',
      });
      expect(workspace.activeApp, DeskApp.notes);
    },
  );

  test(
    'virtual dock opens browser and touchpad sends normalized page coordinates',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      final icon = dockItemRect(dockIndex(DeskApp.browser)).center;
      workspace.dispatch({
        'type': 'pointerMove',
        'dx': icon.dx - workspace.cursor.dx,
        'dy': icon.dy - workspace.cursor.dy,
      });
      workspace.dispatch({'type': 'click'});
      expect(workspace.activeApp, DeskApp.browser);
      final body = workspace.windows.last.visibleRect;
      workspace.dispatch({
        'type': 'pointerMove',
        'dx': body.center.dx - workspace.cursor.dx,
        'dy': body.top + 200 - workspace.cursor.dy,
      });
      workspace.dispatch({'type': 'click'});
      expect(workspace.browserCommand!['type'], 'click');
      expect(workspace.browserCommand!['x'], inInclusiveRange(0, 1));
      workspace.dispatch({'type': 'browserScroll', 'dy': 380});
      expect(workspace.browserCommand!['dy'], 380);
    },
  );
}
