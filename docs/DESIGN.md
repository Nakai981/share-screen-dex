# SideScreen design

The phone is a physical controller; the large display is the workspace. The UI gives the touchpad a broad, textured area and reserves the large display for readable notes and movable windows.

Palette: paper `#F5F7F9`, ink `#18313F`, blue `#3864DE`, mint `#A6D4CA`, divider `#E2E8ED`. Be Vietnam Pro is bundled at regular, semibold and bold weights so Vietnamese text remains consistent without network access.

The distinctive element is the folded ribbon wallpaper, drawn in Flutter so it scales to a monitor. The remaining interface uses quiet surfaces and real connection information. A preview is labeled as a preview until the native host reports an active external presentation.

The responsive layouts serve the same session: stacked controls on a phone; a controller column and a larger interactive workspace preview on wide screens. Window actions and direct preview interactions share the same domain controller as the native external display.

Version 0.2 adds a real browser window with a compact address toolbar and a bundled interactive HTML demo. Native devices use the system WebView; web preview uses an iframe and offers an external-tab action for sites that block embedding.

Version 0.4 uses critically damped springs with perceptual durations of 360 ms for opening, 220 ms for closing and 380 ms for arrangement/maximize. Fresh windows appear near their final scale; minimizing/restoring follows a scale trajectory to the Dock. This is macOS-inspired Flutter motion. Content is laid out at its destination once, reused as the AnimatedBuilder child, and isolated by a RepaintBoundary. Direct dragging stays immediate. Minimized windows keep their widget subtree so browser and address drafts survive. Reduced-motion preferences disable these transitions.

The dock magnifies and lifts the hovered icon, gently moves neighboring icons, and shows a floating label. Opening an app triggers a short bounce. The phone's virtual cursor uses the same hit regions as the physical mouse.

The taskbar is now a full-width surface inset 32 logical points from the bottom by default. The bottom inset is adjustable between 16 and 96; phone-side recovery uses at least 64. Maximized and arranged windows reserve this area. New apps automatically tile without overlap; on very narrow displays older apps minimize when they cannot fit at a readable minimum size. Moving/resizing deliberately switches to free arrangement. Old session layouts migrate to tiles once.

The phone's hardware-control page renders a lightweight window map, rather than duplicating WebViews. Mouse/AssistiveTouch positions map directly to the shared desktop coordinates. The primary scene retains keyboard focus and provides normal TextFields for system IME input, with application shortcuts around them. iPhone external scenes remain noninteractive; no direct external-scene mouse support or physical-device validation is claimed.

Version 0.5 separates iOS desktop chrome from platform-view composition: an ExternalDesktopOverlay is a UIWindow sibling above the Flutter root, hosting the taskbar and a CAShapeLayer mint cursor. Flutter suppresses its duplicate taskbar/cursor only after the native host advertises nativeChrome. The overlay ignores touches and does not take the phone's key window. Platform-view descendants cannot reorder this sibling beneath their root.

The external scene owns a FlutterSceneLifeCycleProvider instead of calling FlutterSceneDelegate's connection implementation. The latter contains a legacy path that can migrate an AppDelegate root/window into a newly connected scene. Explicit provider forwarding keeps plugin lifecycle events while preserving the external window and the phone's keyboard owner.

Cursor-only movement notifies a separate pointer layer and uses a two-number bridge message when supported. Notes and window widgets stay mounted without rebuilds. Native taskbar structure updates only when its dimensions, running apps or active app change; cursor position updates disable implicit Core Animation actions. Dart and native cursor geometry use the same 16×20 logical size, adjustable between 0.7× and 1.5×.

Opening an app retiles even after a manual move disabled automatic layout. Navigating an already-open browser does not undo an explicit maximize. Layout version 3 migrates overlapping/free layouts from older sessions once.

The desktop now expands into the full constraints, including when a monitor is larger than the logical canvas. The default layout keeps a logical height of 900 and adapts its width to the external viewport, centering the dock and maintaining consistent pointer hit regions. The fixed 16:10 mode remains optional. Phone rotation does not report an external viewport. iOS creates its external UIWindow in the scene's own coordinate space with overscan compensation disabled.

Text input uses installed system IMEs. Android can receive optional locale hints; iPhone users select their installed keyboard with the system globe control. Snapshot echoes do not reset the composing range or move the caret. Google is the search provider; the web preview explains and offers an external tab instead of trying to embed Google in an iframe.
