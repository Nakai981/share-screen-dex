import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/platform/chrome_launcher.dart';
import 'package:side_screen/platform/display_bridge.dart';
import 'package:side_screen/ui/chrome_action.dart';
import 'package:side_screen/ui/hardware_controller_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(DisplayBridge.channelName);
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'Chrome accepts web pages, preserves queries and rejects app/local schemes',
    () {
      expect(
        chromeLaunchAddress(browserHome).toString(),
        'https://www.google.com/',
      );
      const address =
          'https://www.google.com/search?q=flutter%20desktop&hl=vi#top';
      expect(chromeLaunchAddress(address).toString(), address);
      expect(chromeLaunchAddress('http://example.com/path').scheme, 'http');
      for (final value in [
        browserDemo,
        'javascript:alert(1)',
        'file:///tmp/index.html',
        'https:///missing',
        'data:text/html,test',
        'googlechrome://www.google.com',
        '',
      ]) {
        expect(
          () => chromeLaunchAddress(value),
          throwsA(isA<ChromeLaunchException>()),
        );
      }
    },
  );

  testWidgets(
    'phone Chrome button launches current URL without changing the browser session',
    (tester) async {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'https://www.google.com/search?q=flutter%20desktop#top',
      });
      workspace.dispatch({'type': 'notes', 'text': 'Giữ nội dung'});
      final before = workspace.snapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChromePhoneAction(workspace: workspace)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('phone-open-chrome')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'openChrome');
      expect(calls.single.arguments, {
        'url': 'https://www.google.com/search?q=flutter%20desktop#top',
      });
      expect(workspace.snapshot(), before);
      expect(
        find.textContaining('Chrome mở riêng trên điện thoại'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'missing Chrome shows the native error and does not fall back to another browser',
    (tester) async {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(
              code: 'chrome_unavailable',
              message: 'Chưa cài Google Chrome trên điện thoại.',
            );
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChromePhoneAction(workspace: workspace)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('phone-open-chrome')));
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa cài Google Chrome trên điện thoại.'),
        findsOneWidget,
      );
      expect(calls, hasLength(1));
      expect(calls.single.arguments, {'url': 'https://www.google.com/'});
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'full-screen controller exposes Chrome in its phone menu and keeps the workspace',
    (tester) async {
      final workspace = WorkspaceController();
      addTearDown(workspace.dispose);
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'https://example.com/',
      });
      final before = workspace.snapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareControllerPage(workspace: workspace, fullScreen: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Điều khiển'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở Chrome trên điện thoại'));
      await tester.pumpAndSettle();
      expect(calls.single.arguments, {'url': 'https://example.com/'});
      expect(workspace.snapshot(), before);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
