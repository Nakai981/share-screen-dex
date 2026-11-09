import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testDesktopOverlayStaysAboveContentWithoutCapturingTouches() async {
    await MainActor.run {
      let window = ExternalWorkspaceWindow(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
      window.addSubview(UIView(frame: window.bounds))
      window.installDesktopOverlay()
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

}
