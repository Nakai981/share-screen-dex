# iPhone external browser geometry — 0.10

The reported screenshot contains a loaded Google page in a small top-left rectangle that overlaps the browser toolbar. The remaining browser area is white. This is a native-view size/position problem; loading/error handling alone cannot correct it.

Flutter's [platform-view compositor](https://api.flutter.dev/ios-embedder/_flutter_platform_views_controller_8mm_source.html) uses the main display scale for frame conversion. SideScreen 0.10 hosts the plugin-owned WKWebView directly on the external UIWindowScene, outside that conversion, using the plugin's [public native API](https://pub.dev/packages/webview_flutter_wkwebview#external-native-api). The Flutter placeholder, native frame and cursor share the domain's browser viewport geometry.

## Full rebuild on a Mac

Use the Xcode/SDK version required by the project's scene-accessory APIs (Xcode 27 SDK or later), then:

```sh
git pull
flutter clean
flutter pub get
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```

Select the physical iPhone, sign with your development team and run from Xcode. Hot reload alone cannot install the Swift host or the new native bridge methods. Confirm **SideScreen 0.10** in settings. Windows Flutter checks do not compile the Swift changes.

## Device checks

1. Connect the monitor and open the bundled interactive page. Content must begin below the address toolbar, span the browser body and stop above the footer. It must not appear at the global top-left or over the title/address bars.
2. Search Google and open a result. Google may still show a network/CAPTCHA challenge; distinguish that rendered page from an incorrectly sized WKWebView.
3. Minimize/restore through the Dock. Confirm the same page survives. Restore the window and move/resize it; the web content must follow its body rectangle.
4. Open notes in front, including partially overlapping restored windows. Web content must disappear under the foreground windows and reappear when they move/minimize/close. Closed notes must not remain above the browser.
5. Enlarge the demo/video and use **Thu nhỏ video**. Check the cursor, Dock and header controls, then reconnect with a 16:10 monitor if available.

RunnerTests adds native geometry/ownership/masking tests. They are pending Xcode execution, as is physical iPhone validation. Dart tests cover viewport dimensions, foreground-region subtraction, pointer agreement and the attachment-channel contract using mocks; they do not run WebKit.
