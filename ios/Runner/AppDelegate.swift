import Flutter
import UIKit
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    ExternalDisplayCoordinator.shared.attachPrimary(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

/// The phone owns the state; the secondary engine only mirrors it.
final class ExternalDisplayCoordinator {
  static let shared = ExternalDisplayCoordinator()
  private let channelName = "dev.sidescreen/display"
  private let storageKey = "side_screen.workspace.v1"
  private let engines = FlutterEngineGroup(name: "sidescreen.displays", project: nil)
  private var primary: FlutterMethodChannel?
  private var secondary: FlutterMethodChannel?
  private var externalEngine: FlutterEngine?
  private weak var externalScene: UIWindowScene?
  private weak var desktopOverlay: ExternalDesktopOverlay?
  private weak var browserHost: ExternalBrowserHost?
  private var browserRegistrar: FlutterPluginRegistrar?
  private let browserViews = NSHashTable<WKWebView>.weakObjects()
  private var state: [String: Any]?
  private var accessoryRegistration: AnyObject?
  private weak var accessoryOwner: UIViewController?
  private var observers: [NSObjectProtocol] = []

  private init() {
    if let data = UserDefaults.standard.data(forKey: storageKey),
       let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      state = saved
    }
    for notification in [UIScreen.didConnectNotification, UIScreen.didDisconnectNotification] {
      observers.append(NotificationCenter.default.addObserver(
        forName: notification, object: nil, queue: .main
      ) { [weak self] _ in self?.notifyStatus() })
    }
  }

  func attachPrimary(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    primary = channel
    bind(channel, external: false)
  }

  /// iOS 27 requires a registered accessory instead of automatic scene delivery.
  /// Build this target with Xcode 27 SDK or later; it still runs on iOS 15+.
  func registerAccessory(on controller: UIViewController) {
    if #available(iOS 27.0, *) {
      guard accessoryOwner !== controller else { return }
      unregisterAccessory()
      let configuration = UISceneConfiguration()
      configuration.delegateClass = ExternalDisplaySceneDelegate.self
      let accessory = UISceneAccessory.externalNonInteractive(sceneConfiguration: configuration)
      accessoryRegistration = controller.registerSceneAccessory(accessory)
      accessoryOwner = controller
    }
    notifyStatus()
  }

  func unregisterAccessory() {
    if #available(iOS 27.0, *),
       let registration = accessoryRegistration as? UISceneAccessoryRegistration {
      accessoryOwner?.unregisterSceneAccessory(registration)
    }
    accessoryRegistration = nil
    accessoryOwner = nil
  }

  func connect(_ scene: UIWindowScene) -> FlutterEngine {
    disconnect()
    externalScene = scene
    let engine = engines.makeEngine(withEntrypoint: "externalDisplayMain", libraryURI: nil)
    externalEngine = engine
    GeneratedPluginRegistrant.register(with: engine)
    browserRegistrar = engine.registrar(forPlugin: "SideScreenExternalBrowserHost")
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)
    secondary = channel
    bind(channel, external: true)
    UIApplication.shared.isIdleTimerDisabled = true
    notifyStatus()
    return engine
  }

  func disconnect() {
    browserHost?.detach()
    browserHost = nil
    browserRegistrar = nil
    browserViews.removeAllObjects()
    desktopOverlay = nil
    secondary?.setMethodCallHandler(nil)
    secondary = nil
    externalEngine?.destroyContext()
    externalEngine = nil
    externalScene = nil
    UIApplication.shared.isIdleTimerDisabled = false
    notifyStatus()
  }

  func attachOverlay(_ overlay: ExternalDesktopOverlay) {
    desktopOverlay = overlay
    overlay.apply(state ?? [:])
    notifyStatus()
  }

  func attachBrowserHost(_ host: ExternalBrowserHost) {
    browserHost = host
    host.apply(state ?? [:])
  }

  private func bind(_ channel: FlutterMethodChannel, external: Bool) {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "initialize":
        result(["status": self.status(), "state": self.state as Any? ?? NSNull()])
      case "refresh":
        self.notifyStatus()
        result(nil)
      case "openChrome":
        guard let args = call.arguments as? [String: Any],
              let value = args["url"] as? String, let url = Self.chromeURL(for: value) else {
          result(FlutterError(code: "invalid_url", message: "Địa chỉ Chrome không hợp lệ.", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          if opened { result(nil) }
          else { result(FlutterError(code: "chrome_unavailable", message: "Chưa cài Google Chrome hoặc không mở được Chrome trên điện thoại.", details: nil)) }
        }
      case "attachExternalBrowser":
        guard external, let args = call.arguments as? [String: Any],
              let identifier = args["identifier"] as? NSNumber,
              let registrar = self.browserRegistrar, let host = self.browserHost,
              let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
                forIdentifier: identifier.int64Value, withPluginRegistrar: registrar) else {
          result(FlutterError(code: "external_browser_unavailable", message: "External browser host is not ready", details: nil))
          return
        }
        self.browserViews.add(webView)
        host.attach(webView, identifier: identifier.int64Value)
        host.apply(self.state ?? [:])
        result(nil)
      case "updateExternalBrowser":
        if external, let args = call.arguments as? [String: Any],
           let identifier = args["identifier"] as? NSNumber {
          self.browserHost?.present(identifier: identifier.int64Value,
                                    visible: args["visible"] as? Bool == true,
                                    progress: (args["progress"] as? NSNumber)?.intValue ?? 100)
        }
        result(nil)
      case "detachExternalBrowser":
        if external, let args = call.arguments as? [String: Any],
           let identifier = args["identifier"] as? NSNumber {
          self.browserHost?.detach(identifier: identifier.int64Value)
        }
        result(nil)
      case "publishState":
        if !external, let next = call.arguments as? [String: Any] {
          let previous = self.state?["browserCommand"] as? [String: Any]
          let command = next["browserCommand"] as? [String: Any]
          self.collectBrowserViews()
          if command?["type"] as? String == "exitFullscreen",
             (command?["serial"] as? NSNumber) != (previous?["serial"] as? NSNumber) {
            for webView in self.browserViews.allObjects {
              webView.closeAllMediaPresentations(completionHandler: nil)
            }
          }
          self.state = next
          self.desktopOverlay?.apply(next)
          self.browserHost?.apply(next)
          self.secondary?.invokeMethod("stateChanged", arguments: next)
        }
        result(nil)
      case "publishPointer":
        if !external, let pointer = call.arguments as? [String: Any] {
          if self.browserViews.allObjects.isEmpty { self.collectBrowserViews() }
          var next = self.state ?? [:]
          for key in ["cursorX", "cursorY"] {
            if let number = pointer[key] as? NSNumber, number.doubleValue.isFinite {
              next[key] = number
            }
          }
          self.state = next
          self.desktopOverlay?.applyPointer(pointer)
          self.secondary?.invokeMethod("pointerChanged", arguments: pointer)
        }
        result(nil)
      case "saveState":
        if !external, let next = call.arguments as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: next) {
          UserDefaults.standard.set(data, forKey: self.storageKey)
        }
        result(nil)
      case "dispatchAction":
        if external, let action = call.arguments as? [String: Any] {
          self.primary?.invokeMethod("action", arguments: action)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func status() -> [String: Any] {
    // UIScreen.screens is retained only as a compatibility fallback to report
    // physical connection before an external scene is delivered by the system.
    let screen = externalScene?.screen ?? UIScreen.screens.first(where: { $0 !== UIScreen.main })
    var value: [String: Any] = [
      "nativeAvailable": true,
      "nativeChrome": externalEngine != nil && desktopOverlay != nil,
      "supportsPointerUpdates": true,
      "connected": screen != nil,
      "presenting": externalEngine != nil,
    ]
    if let screen = screen {
      value["name"] = "Màn hình ngoài"
      value["width"] = Int(screen.nativeBounds.width)
      value["height"] = Int(screen.nativeBounds.height)
    }
    return value
  }

  static func chromeURL(for value: String) -> URL? {
    guard var components = URLComponents(string: value),
          let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
          let host = components.host, !host.isEmpty else { return nil }
    components.scheme = scheme == "https" ? "googlechromes" : "googlechrome"
    return components.url
  }

  private func collectBrowserViews() {
    func visit(_ view: UIView) {
      if let browser = view as? WKWebView { browserViews.add(browser) }
      for child in view.subviews { visit(child) }
    }
    for window in externalScene?.windows ?? [] { visit(window) }
  }

  func notifyStatus() {
    let current = status()
    primary?.invokeMethod("displayChanged", arguments: current)
    secondary?.invokeMethod("displayChanged", arguments: current)
  }
}
