# SideScreen design

The phone is a physical controller; the large display is the workspace. The UI gives the touchpad a broad, textured area and reserves the large display for readable notes and movable windows.

Palette: paper `#F5F7F9`, ink `#18313F`, blue `#3864DE`, mint `#A6D4CA`, divider `#E2E8ED`. Be Vietnam Pro is bundled at regular, semibold and bold weights so Vietnamese text remains consistent without network access.

The distinctive element is the folded ribbon wallpaper, drawn in Flutter so it scales to a monitor. The remaining interface uses quiet surfaces and real connection information. A preview is labeled as a preview until the native host reports an active external presentation.

The responsive layouts serve the same session: stacked controls on a phone; a controller column and a larger interactive workspace preview on wide screens. Window actions and direct preview interactions share the same domain controller as the native external display.

Version 0.2 adds a real browser window with a compact address toolbar and a bundled interactive HTML demo. Native devices use the system WebView; web preview uses an iframe and offers an external-tab action for sites that block embedding.

Version 0.3 window entrance takes 300 ms from the app's dock icon. Closing reverses over 220 ms; maximize/restore interpolates transforms over 280 ms. Content is laid out at its destination once, reused as the AnimatedBuilder child, and isolated by a RepaintBoundary. Direct dragging stays immediate. Minimized windows keep their widget subtree so browser and address drafts survive. Reduced-motion preferences disable these transitions.

The dock magnifies and lifts the hovered icon, gently moves neighboring icons, and shows a floating label. Opening an app triggers a short bounce. The phone's virtual cursor uses the same hit regions as the physical mouse.

The desktop now expands into the full constraints, including when a monitor is larger than the logical canvas. The default layout keeps a logical height of 900 and adapts its width to the external viewport, centering the dock and maintaining consistent pointer hit regions. The fixed 16:10 mode remains optional. Phone rotation does not report an external viewport. iOS creates its external UIWindow in the scene's own coordinate space with overscan compensation disabled.

Text input uses installed system IMEs. Android can receive optional locale hints; iPhone users select their installed keyboard with the system globe control. Snapshot echoes do not reset the composing range or move the caret. Google is the search provider; the web preview explains and offers an external tab instead of trying to embed Google in an iframe.
