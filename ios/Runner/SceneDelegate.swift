import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let controller = window?.rootViewController {
      ExternalDisplayCoordinator.shared.registerAccessory(on: controller)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if let controller = window?.rootViewController {
      ExternalDisplayCoordinator.shared.registerAccessory(on: controller)
    }
    ExternalDisplayCoordinator.shared.notifyStatus()
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    ExternalDisplayCoordinator.shared.unregisterAccessory()
    super.sceneDidDisconnect(scene)
  }
}

class ExternalDisplaySceneDelegate: FlutterSceneDelegate {
  private var engine: FlutterEngine?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    // Use the monitor's coordinate space, independently of phone orientation.
    windowScene.screen.overscanCompensation = .none
    let nextEngine = ExternalDisplayCoordinator.shared.connect(windowScene)
    engine = nextEngine
    registerSceneLifeCycle(with: nextEngine)
    let nextWindow = UIWindow(windowScene: windowScene)
    nextWindow.frame = windowScene.coordinateSpace.bounds
    nextWindow.rootViewController = FlutterViewController(engine: nextEngine, nibName: nil, bundle: nil)
    nextWindow.backgroundColor = UIColor(red: 23/255, green: 58/255, blue: 70/255, alpha: 1)
    window = nextWindow
    nextWindow.isHidden = false
    // Preserve the phone's key window, keyboard and interaction focus.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    super.sceneDidDisconnect(scene)
    window?.isHidden = true
    window?.rootViewController = nil
    window = nil
    if let current = engine { unregisterSceneLifeCycle(with: current) }
    engine = nil
    ExternalDisplayCoordinator.shared.disconnect()
  }
}
