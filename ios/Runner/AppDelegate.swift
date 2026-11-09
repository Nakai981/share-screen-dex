import Flutter
import UIKit

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
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)
    secondary = channel
    bind(channel, external: true)
    UIApplication.shared.isIdleTimerDisabled = true
    notifyStatus()
    return engine
  }

  func disconnect() {
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

  private func bind(_ channel: FlutterMethodChannel, external: Bool) {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "initialize":
        result(["status": self.status(), "state": self.state as Any? ?? NSNull()])
      case "refresh":
        self.notifyStatus()
        result(nil)
      case "publishState":
        if !external, let next = call.arguments as? [String: Any] {
          self.state = next
          self.desktopOverlay?.apply(next)
          self.secondary?.invokeMethod("stateChanged", arguments: next)
        }
        result(nil)
      case "publishPointer":
        if !external, let pointer = call.arguments as? [String: Any] {
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

  func notifyStatus() {
    let current = status()
    primary?.invokeMethod("displayChanged", arguments: current)
    secondary?.invokeMethod("displayChanged", arguments: current)
  }
}
