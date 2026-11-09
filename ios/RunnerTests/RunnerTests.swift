import Flutter
import UIKit
import WebKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testChromeURLConversionPreservesWebAddressAndBlocksOtherSchemes() {
    XCTAssertEqual(ExternalDisplayCoordinator.chromeURL(for: "https://www.google.com/search?q=flutter%20desktop#top")?.absoluteString,
                   "googlechromes://www.google.com/search?q=flutter%20desktop#top")
    XCTAssertEqual(ExternalDisplayCoordinator.chromeURL(for: "http://example.com/path")?.absoluteString,
                   "googlechrome://example.com/path")
    for value in ["javascript:alert(1)", "file:///tmp/index.html", "https:///", "sidescreen://demo", ""] {
      XCTAssertNil(ExternalDisplayCoordinator.chromeURL(for: value))
    }
  }

  func testExternalBrowserUsesFullMonitorPointsInsteadOfPhonePixelRatio() async {
    await MainActor.run {
      for size in [CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1600), CGSize(width: 3840, height: 2160)] {
        let host = ExternalBrowserHost(frame: CGRect(origin: .zero, size: size))
        let view = WKWebView(frame: .zero)
        let width = 900 * size.width / size.height
        let rect: [String: Any] = ["x": 17, "y": 117, "width": width - 34, "height": 600]
        host.attach(view, identifier: 7)
        host.apply(["displayAspect": size.width / size.height, "fullScreen": true,
                    "browserViewport": ["frame": rect, "visibleRegions": [rect]]])
        XCTAssertFalse(host.isHidden)
        XCTAssertTrue(view.superview === host.content)
        XCTAssertEqual(host.content.frame.minX, 17 * size.height / 900, accuracy: 0.01)
        XCTAssertEqual(host.content.frame.minY, 117 * size.height / 900, accuracy: 0.01)
        XCTAssertEqual(host.content.frame.width, (width - 34) * size.height / 900, accuracy: 0.01)
        XCTAssertGreaterThan(view.bounds.width, size.width * 0.9)
        XCTAssertEqual(view.frame, host.content.bounds)
      }
    }
  }

  func testExternalBrowserVisibilityMaskAndStaleDetach() async {
    await MainActor.run {
      let host = ExternalBrowserHost(frame: CGRect(x: 0, y: 0, width: 1600, height: 900))
      let first = WKWebView(frame: .zero)
      let second = WKWebView(frame: .zero)
      let rect: [String: Any] = ["x": 17, "y": 117, "width": 1566, "height": 600]
      let half: [String: Any] = ["x": 17, "y": 117, "width": 700, "height": 600]
      host.attach(first, identifier: 7)
      host.attach(second, identifier: 9)
      host.apply(["displayAspect": 16.0 / 9.0, "browserViewport": ["frame": rect, "visibleRegions": [half]]])
      host.detach(identifier: 7)
      XCTAssertTrue(host.webView === second)
      XCTAssertNil(first.superview)
      let mask = host.content.layer.mask as! CAShapeLayer
      XCTAssertTrue(mask.path!.contains(CGPoint(x: 100, y: 100)))
      XCTAssertFalse(mask.path!.contains(CGPoint(x: 1000, y: 100)))
      host.present(identifier: 9, visible: false, progress: 30)
      XCTAssertTrue(host.isHidden)
      host.present(identifier: 9, visible: true, progress: 100)
      XCTAssertFalse(host.isHidden)
      host.apply(["browserViewport": ["frame": rect, "visibleRegions": []]])
      XCTAssertTrue(host.isHidden)
      host.detach(identifier: 9)
      XCTAssertNil(second.superview)
    }
  }

  func testExternalBrowserWindowDoesNotOwnInputOrCoverChrome() async {
    await MainActor.run {
      let browser = ExternalBrowserWindow(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
      browser.installBrowserHost()
      let chrome = ExternalDesktopChromeWindow(frame: browser.frame)
      chrome.installDesktopOverlay()
      XCTAssertEqual(browser.browserHost.frame, browser.bounds)
      XCTAssertGreaterThan(browser.windowLevel.rawValue, UIWindow.Level.normal.rawValue)
      XCTAssertLessThan(browser.windowLevel.rawValue, chrome.windowLevel.rawValue)
      XCTAssertFalse(browser.isUserInteractionEnabled)
      XCTAssertFalse(browser.isKeyWindow)
      XCTAssertNil(browser.hitTest(CGPoint(x: 100, y: 100), with: nil))
    }
  }

  func testWindowControlsFollowNotesAndDisappearWhenAllWindowsClose() async {
    await MainActor.run {
      let overlay = ExternalDesktopOverlay(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
      overlay.apply(["fullScreen": true, "displayAspect": 16.0 / 9.0,
                     "windows": [["app": "notes", "maximized": true]]])
      XCTAssertFalse(overlay.windowControls.isHidden)
      XCTAssertEqual(overlay.windowControls.frame.maxX, 1899.6, accuracy: 0.01)
      XCTAssertEqual(overlay.windowControls.frame.minY, 44.4, accuracy: 0.01)
      XCTAssertEqual(overlay.windowControls.subviews.count, 3)
      overlay.apply(["windows": [["app": "notes", "x": 750, "y": 224, "width": 550]]])
      XCTAssertEqual(overlay.windowControls.frame.minY, 270, accuracy: 0.01)
      overlay.apply(["windows": []])
      XCTAssertTrue(overlay.windowControls.isHidden)
    }
  }

  func testVideoExitControlStaysOutsideWebContentAndTracksWindow() async {
    await MainActor.run {
      let overlay = ExternalDesktopOverlay(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
      overlay.apply(["fullScreen": true, "displayAspect": 16.0 / 9.0, "viewportHeight": 1080,
                     "windows": [["app": "browser", "maximized": true]]])
      XCTAssertFalse(overlay.videoExit.isHidden)
      XCTAssertEqual(overlay.videoExit.frame.minY, 92.4, accuracy: 0.01)
      XCTAssertEqual(overlay.videoExit.frame.width, 148.8, accuracy: 0.01)
      overlay.apply(["windows": [["app": "browser"], ["app": "notes"]]])
      XCTAssertTrue(overlay.videoExit.isHidden)
    }
  }

  func testDesktopOverlayStaysAboveContentWithoutCapturingTouches() async {
    await MainActor.run {
      let window = ExternalDesktopChromeWindow(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
      window.addSubview(UIView(frame: window.bounds))
      window.installDesktopOverlay()
      XCTAssertGreaterThan(window.windowLevel.rawValue, UIWindow.Level.alert.rawValue)
      XCTAssertFalse(window.isUserInteractionEnabled)
      XCTAssertNil(window.hitTest(CGPoint(x: 100, y: 100), with: nil))
      XCTAssertTrue(window.subviews.last === window.desktopOverlay)
      XCTAssertFalse(window.desktopOverlay.isUserInteractionEnabled)
      XCTAssertNil(window.desktopOverlay.hitTest(CGPoint(x: 100, y: 100), with: nil))
      // Simulate an additional UIKit content sibling inserted after startup.
      window.addSubview(UIView(frame: window.bounds))
      window.setNeedsLayout()
      window.layoutIfNeeded()
      XCTAssertTrue(window.subviews.last === window.desktopOverlay)
    }
  }

  func testCursorMovesWithoutRecreatingTaskbarAndUsesMonitorCoordinates() async {
    await MainActor.run {
      let overlay = ExternalDesktopOverlay(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
      overlay.apply(["fullScreen": true, "displayAspect": 16.0 / 9.0, "safeInset": 32,
                     "cursorX": 100, "cursorY": 100, "windows": [["app": "notes", "minimized": false]]])
      let bar = overlay.subviews.first!
      let cursor = overlay.subviews.last!
      let children = bar.subviews
      XCTAssertEqual(bar.frame.maxY, 1041.6, accuracy: 0.01)
      XCTAssertEqual(cursor.frame.width, 19.2, accuracy: 0.01)
      overlay.applyPointer(["cursorX": 1000, "cursorY": 500])
      XCTAssertEqual(cursor.frame.minX, 1200, accuracy: 0.01)
      XCTAssertEqual(cursor.frame.minY, 600, accuracy: 0.01)
      XCTAssertTrue(overlay.subviews.first === bar)
      XCTAssertEqual(children.count, bar.subviews.count)
      for (before, after) in zip(children, bar.subviews) { XCTAssertTrue(before === after) }
    }
  }

  func testCompactDockKeepsItsPointSizeAcrossMonitors() async {
    await MainActor.run {
      for size in [CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1600), CGSize(width: 3840, height: 2160)] {
        let overlay = ExternalDesktopOverlay(frame: CGRect(origin: .zero, size: size))
        overlay.apply(["fullScreen": true, "displayAspect": size.width / size.height,
                       "viewportHeight": size.height, "safeInset": 8])
        let bar = overlay.subviews.first!
        XCTAssertEqual(bar.frame.width, 320, accuracy: 0.01)
        XCTAssertEqual(bar.frame.height, 72, accuracy: 0.01)
        XCTAssertEqual(size.height - bar.frame.maxY, 8, accuracy: 0.01)
        XCTAssertEqual(bar.frame.midX, size.width / 2, accuracy: 0.01)
        XCTAssertLessThan(bar.frame.maxY, size.height)
      }
    }
  }

}
