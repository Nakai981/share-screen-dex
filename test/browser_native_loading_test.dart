import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:side_screen/domain/workspace.dart';
import 'package:side_screen/ui/browser/browser_surface_native.dart';

class TestBrowserPlatform extends WebViewPlatform {
  late TestController controller;
  late TestNavigation navigation;
  int mountedViews = 0;
  int disposedViews = 0;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = TestController(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => navigation = TestNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => TestView(params, this);
}

class TestController extends PlatformWebViewController {
  TestController(super.params) : super.implementation();
  final requests = <Uri>[];
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<String?> getUserAgent() async => 'AppleWebKit/619.1.26';
  @override
  Future<void> setUserAgent(String? userAgent) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> runJavaScript(String script) async {}
}

class TestNavigation extends PlatformNavigationDelegate {
  TestNavigation(super.params) : super.implementation();
  late PageEventCallback started, finished;
  late WebResourceErrorCallback failed;
  late UrlChangeCallback? location;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    failed = callback;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback? callback) async {
    location = callback;
  }
}

class TestView extends PlatformWebViewWidget {
  TestView(super.params, this.platform) : super.implementation();
  final TestBrowserPlatform platform;
  @override
  Widget build(BuildContext context) => ViewProbe(platform: platform);
}

class ViewProbe extends StatefulWidget {
  const ViewProbe({super.key, required this.platform});
  final TestBrowserPlatform platform;
  @override
  State<ViewProbe> createState() => _ViewProbeState();
}

class _ViewProbeState extends State<ViewProbe> {
  @override
  void initState() {
    super.initState();
    widget.platform.mountedViews++;
  }

  @override
  void dispose() {
    widget.platform.disposedViews++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.white);
}

void main() {
  late TestBrowserPlatform platform;
  late WorkspaceController workspace;
  late List<(String, bool)> locations;
  setUp(() {
    platform = TestBrowserPlatform();
    WebViewPlatform.instance = platform;
    workspace = WorkspaceController();
    locations = [];
    workspace.dispatch({
      'type': 'browserNavigate',
      'url': 'https://www.google.com/search?q=flutter',
    });
  });
  tearDown(() {
    workspace.dispose();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: workspace.sceneChanges,
            builder: (context, _) => browserSurface(
              url: workspace.browserUrl,
              reload: workspace.browserReload,
              interactive: true,
              workspace: workspace,
              onNavigate: (url, replace) => locations.add((url, replace)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.controller.requests, hasLength(1));
  }

  testWidgets(
    'redirect echoes and unrelated scene updates never reload an in-flight page',
    (tester) async {
      await mount(tester);
      platform.navigation.started('https://consent.google.com/m');
      platform.navigation.started(
        'https://www.google.com/search?q=flutter&consent=1',
      );
      workspace.dispatch({'type': 'wallpaper'});
      await tester.pump();
      for (final (url, replace) in locations.toList()) {
        workspace.dispatch({
          'type': 'browserLocation',
          'url': url,
          'replace': replace,
        });
        await tester.pump();
      }
      expect(platform.controller.requests, hasLength(1));
      workspace.dispatch({
        'type': 'browserNavigate',
        'url': 'https://www.google.com/search?q=dart',
      });
      await tester.pump();
      expect(platform.controller.requests.last.queryParameters['q'], 'dart');
      expect(platform.controller.requests, hasLength(2));
      platform.navigation.finished(workspace.browserUrl);
      platform.navigation.location!(
        const UrlChange(url: 'https://www.google.com/search?q=dart#next'),
      );
      expect(locations.last, (
        'https://www.google.com/search?q=dart#next',
        false,
      ));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed page retries immediately without destroying its native view',
    (tester) async {
      await mount(tester);
      for (final failure in [
        WebResourceError(
          errorCode: -999,
          description: 'cancelled',
          isForMainFrame: true,
        ),
        WebResourceError(
          errorCode: -2,
          description: 'ad failed',
          isForMainFrame: false,
        ),
      ]) {
        platform.navigation.failed(failure);
      }
      await tester.pump();
      expect(find.text('Thử lại'), findsNothing);
      platform.navigation.failed(
        WebResourceError(
          errorCode: -1009,
          description: 'offline',
          isForMainFrame: true,
        ),
      );
      await tester.pump();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(platform.mountedViews, 1);
      expect(platform.disposedViews, 0);
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      expect(find.text('Thử lại'), findsNothing);
      expect(platform.controller.requests, hasLength(2));
      expect(platform.mountedViews, 1);
      platform.navigation.finished(workspace.browserUrl);
      await tester.pumpWidget(const SizedBox());
      expect(platform.disposedViews, 1);
    },
  );

  testWidgets(
    'stalled loading offers recovery instead of an endless blank surface',
    (tester) async {
      await mount(tester);
      await tester.pump(const Duration(seconds: 31));
      expect(find.textContaining('mất quá lâu'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      expect(find.textContaining('mất quá lâu'), findsNothing);
      platform.navigation.finished(workspace.browserUrl);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
