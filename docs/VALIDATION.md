# Validation

Environment: Windows 10, Flutter 3.47.8, Dart 3.13.7, Android SDK 36. Android tests use a separate, read-only Pixel 10 Pro emulator with the installed Android 37.2 system image.

Verified:

- `flutter analyze`: no issues.
- Version 0.3 with YouTube web fix `flutter test`: 37 passing tests, including intermediate animation states, reuse of contents across animation ticks, dock mouse/virtual hover, reduced motion, browser history/redirects, Google search URLs, URL validation, private page-input commands, minimizing without losing a draft address, narrow layouts, Vietnamese IME composition, language hints and state mirroring. YouTube tests cover home/channel/search fallback, watch/share/short/live/embed links, start times and spoofed hosts.
- Adaptive canvas and wallpaper bounds verified at 1920×1080 and 2560×1600: the content reaches all four edges. Domain tests cover dock/cursor/maximize geometry on 16:9, 16:10 and ultrawide, mode switching and snapshot restoration.
- Android version 0.3 also renders edge-to-edge on a native dedicated 1920×1080 simulated display, with persisted `displayAspect: 1.7777777777777777` and `fullScreen: true`. Screenshot: `artifacts/android-fullscreen-v0.3.png`.
- Chrome version 0.3: language selector lists system/Vietnamese/English/Japanese/Korean/Chinese, Fullscreen API enters successfully, and searching `bộ gõ tiếng Việt` produces the matching `www.google.com/search` URL and opens Google in a separate tab.
- YouTube web fix: entering `www.youtube.com` shows the external-tab explanation with zero iframes, avoiding the refused-to-connect page. A watch link creates `www.youtube.com/embed/M7lc1UVf-VE` with the requested start time and real page origin; Chrome loads the official player with its video title, thumbnail and Play control. Video playback remains subject to YouTube availability, embedding restrictions and network policy; uninterrupted playback is not claimed.
- `dart format --output=none --set-exit-if-changed lib test`: clean.
- Android debug APK builds with the Kotlin native host.
- Android ARM64 release APK builds with the external Dart entrypoint retained.
- Flutter web release builds with locally bundled rendering resources and fonts.
- Chrome preview renders on wide and narrow layouts; phone note editing updates the desktop; no browser console errors during the checked flow.
- Native Android presentation renders the Flutter desktop on a dedicated 1280×800 simulated display. The screenshot in `artifacts/android-external.png` was captured directly from that display.
- Notes entered through the phone survive app process restart. Unplug removes the presentation; reopening the app with a reconnected display restores the workspace.
- Version 0.2 native Android WebView renders the bundled HTML/JavaScript demo inside the external-display Presentation. The native host attaches the secondary engine to the foreground Activity so the WebView plugin can create its platform view. Screenshot: `artifacts/android-browser-v0.2.png`.
- A real HTTPS website (`https://example.com/`) was entered through the phone controller and rendered by the external-display WebView. Screenshot: `artifacts/android-browser-website-v0.2.png`.
- Chrome browser preview opens the bundled demo, runs its JavaScript counter, navigates between home/demo, and displays the dock hover animation.

Observed limitations:

- This emulator can reject automatic Presentation creation during hot-plug. The app catches the rejection, retries a bounded number of times, and offers retry/reopen guidance. The native smoke test records this limitation explicitly, then verifies reopening with an already connected dedicated presentation display.
- The default simulated Android desktop display may reject Presentation windows. The validated native smoke test uses `own_content_only`, a dedicated presentation display, rather than claiming compatibility with every desktop-mode display.
- No physical phone, cable, HDMI adapter or monitor was attached to this Windows environment. USB-C hardware compatibility and latency still require target-device testing.
- iOS source is implemented, including the iOS 27 scene-accessory path and older scene configuration, but has not been compiled or run on macOS/Xcode here.
- The Android release artifact is ARM64 and uses the development signing key. Store distribution requires release signing and platform release validation.
- Web preview cannot bypass sites' iframe restrictions or read another origin's internal navigation. The external-tab action is available. Virtual page commands on web are supported by the bundled demo; remote sites use direct mouse input. Native WebView commands run within its page context.
- The iOS WebView path has not been compiled or tested on a Mac or iPhone here.
- Version 0.3 iOS external-window coordinate-space/overscan changes have not been compiled or checked on the user's iPhone 15 and 16-inch monitor. A physical-device build is still needed to confirm the reported border issue is fully resolved, including any monitor-side scaling.
- Animation work is reduced by reusing window content and animating transforms rather than repeated layout; no claim of a measured 60/120 fps on physical iPhone hardware is made.
