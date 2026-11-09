import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/platform/display_bridge.dart';
import 'package:side_screen/platform/external_browser_attachment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only iOS external renderers bypass the Flutter platform view', () {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        usesExternalBrowserHost(external: true),
        platform == TargetPlatform.iOS,
      );
      expect(usesExternalBrowserHost(external: false), false);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'native attachment, presentation and disposal retain the same controller identifier',
    () async {
      const channel = MethodChannel(DisplayBridge.channelName);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final host = ExternalBrowserAttachment();
      await host.attach(42);
      await host.present(visible: false, progress: 30);
      await host.present(visible: true, progress: 100);
      await host.detach();
      await host.detach();
      await host.present(visible: true, progress: 100);
      expect(calls.map((c) => c.method), [
        'attachExternalBrowser',
        'updateExternalBrowser',
        'updateExternalBrowser',
        'detachExternalBrowser',
      ]);
      expect(
        calls.every((c) => (c.arguments as Map)['identifier'] == 42),
        true,
      );
      expect(calls[1].arguments, {
        'identifier': 42,
        'visible': false,
        'progress': 30,
      });
    },
  );

  test(
    'browser frame excludes title/address/footer and matches pointer coordinates on all monitors',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      for (final size in [
        const Size(1280, 720),
        const Size(1920, 1080),
        const Size(2560, 1600),
        const Size(3440, 1440),
        const Size(3840, 2160),
      ]) {
        workspace.dispatch({
          'type': 'displayViewport',
          'source': 'renderer',
          'width': size.width,
          'height': size.height,
        });
        workspace.dispatch({'type': 'open', 'app': 'browser'});
        final window = workspace.windows.last.visibleRect;
        final viewport = workspace.browserViewportSnapshot!;
        final raw = viewport['frame'] as Map;
        final frame = Rect.fromLTWH(
          raw['x'] as double,
          raw['y'] as double,
          raw['width'] as double,
          raw['height'] as double,
        );
        expect(frame, browserViewportRect(window));
        expect(frame.top, window.top + browserContentTop);
        expect(frame.bottom, window.bottom - browserContentBottom);
        expect(frame.width, closeTo(workspace.canvasSize.width - 34, 0.001));
        expect(viewport['visibleRegions'], hasLength(1));
        workspace.dispatch({
          'type': 'pointerMove',
          'dx': frame.center.dx - workspace.cursor.dx,
          'dy': frame.center.dy - workspace.cursor.dy,
        });
        expect(workspace.browserPointerPosition, const Offset(.5, .5));
        final physical = Rect.fromLTWH(
          frame.left * size.height / 900,
          frame.top * size.height / 900,
          frame.width * size.height / 900,
          frame.height * size.height / 900,
        );
        expect(physical.width, greaterThan(size.width * .9));
        expect(physical.top, greaterThan(0));
        expect(physical.bottom, lessThan(size.height));
      }
      workspace.dispatch({'type': 'minimize', 'app': 'browser'});
      expect(workspace.browserViewportSnapshot, isNull);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      expect(workspace.snapshot(forStorage: true)['browserViewport'], isNull);
    },
  );

  test(
    'foreground windows mask browser content without holes where their covers overlap',
    () {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({'type': 'open', 'app': 'browser'});
      workspace.dispatch({'type': 'open', 'app': 'notes'});
      expect(workspace.browserViewportSnapshot!['visibleRegions'], isEmpty);
      for (final app in ['notes', 'guide']) {
        workspace.dispatch({'type': 'open', 'app': app});
        workspace.dispatch({'type': 'maximize', 'app': app});
      }
      final frame = browserViewportRect(
        workspace.windows
            .firstWhere((w) => w.app == DeskApp.browser)
            .visibleRect,
      );
      final covers = workspace.windows
          .where((w) => w.app != DeskApp.browser)
          .map((w) => w.visibleRect)
          .toList();
      final regions =
          (workspace.browserViewportSnapshot!['visibleRegions'] as List).map((
            raw,
          ) {
            final r = raw as Map;
            return Rect.fromLTWH(
              r['x'] as double,
              r['y'] as double,
              r['width'] as double,
              r['height'] as double,
            );
          }).toList();
      expect(regions, isNotEmpty);
      for (var i = 0; i < regions.length; i++) {
        for (final cover in covers) {
          expect(regions[i].overlaps(cover), false);
        }
        for (final other in regions.skip(i + 1)) {
          expect(regions[i].overlaps(other), false);
        }
      }
      for (double y = frame.top + 5; y < frame.bottom; y += 13) {
        for (double x = frame.left + 5; x < frame.right; x += 13) {
          final point = Offset(x, y);
          expect(
            regions.any((r) => r.contains(point)),
            !covers.any((r) => r.contains(point)),
          );
        }
      }
    },
  );
}
