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

class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {
  var sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()
  var window: UIWindow?
  private var engine: FlutterEngine?
  private var chromeWindow: ExternalDesktopChromeWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    // Use the monitor's coordinate space, independently of phone orientation.
    windowScene.screen.overscanCompensation = .none
    let nextEngine = ExternalDisplayCoordinator.shared.connect(windowScene)
    engine = nextEngine
    sceneLifeCycleDelegate.registerSceneLifeCycle(with: nextEngine)
    let nextWindow = UIWindow(windowScene: windowScene)
    nextWindow.frame = windowScene.coordinateSpace.bounds
    nextWindow.rootViewController = FlutterViewController(engine: nextEngine, nibName: nil, bundle: nil)
    nextWindow.backgroundColor = UIColor(red: 23/255, green: 58/255, blue: 70/255, alpha: 1)
    window = nextWindow
    nextWindow.isHidden = false
    let chrome = ExternalDesktopChromeWindow(windowScene: windowScene)
    chrome.frame = windowScene.coordinateSpace.bounds
    chrome.installDesktopOverlay()
    chromeWindow = chrome
    chrome.isHidden = false
    ExternalDisplayCoordinator.shared.attachOverlay(chrome.desktopOverlay)
    // Forward plugin lifecycle without FlutterSceneDelegate's legacy migration,
    // which can replace this window with the phone's root view controller.
    sceneLifeCycleDelegate.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  func sceneWillEnterForeground(_ scene: UIScene) { sceneLifeCycleDelegate.sceneWillEnterForeground(scene) }
  func sceneDidBecomeActive(_ scene: UIScene) { sceneLifeCycleDelegate.sceneDidBecomeActive(scene) }
  func sceneWillResignActive(_ scene: UIScene) { sceneLifeCycleDelegate.sceneWillResignActive(scene) }
  func sceneDidEnterBackground(_ scene: UIScene) { sceneLifeCycleDelegate.sceneDidEnterBackground(scene) }

  func sceneDidDisconnect(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidDisconnect(scene)
    chromeWindow?.isHidden = true
    chromeWindow?.rootViewController = nil
    chromeWindow = nil
    window?.isHidden = true
    window?.rootViewController = nil
    window = nil
    if let current = engine { sceneLifeCycleDelegate.unregisterSceneLifeCycle(with: current) }
    engine = nil
    ExternalDisplayCoordinator.shared.disconnect()
  }
}

/// A non-key, touch-transparent window also stays above WebKit's native
/// fullscreen presentation, which can use a different content window.
final class ExternalDesktopChromeWindow: UIWindow {
  let desktopOverlay = ExternalDesktopOverlay(frame: .zero)

  func installDesktopOverlay() {
    windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    if rootViewController == nil {
      let controller = UIViewController()
      controller.view.backgroundColor = .clear
      rootViewController = controller
    }
    if desktopOverlay.superview !== self { addSubview(desktopOverlay) }
    if desktopOverlay.frame != bounds { desktopOverlay.frame = bounds }
    if subviews.last !== desktopOverlay { bringSubviewToFront(desktopOverlay) }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    installDesktopOverlay()
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

final class ExternalDesktopOverlay: UIView {
  private let taskbar = UIView()
  private let brand = UILabel()
  private let arrange = UIImageView(image: UIImage(systemName: "rectangle.split.3x1"))
  private let cursorView = UIView()
  private var icons: [UIImageView] = []
  private var labels: [UILabel] = []
  private var indicators: [UIView] = []
  private var snapshot: [String: Any] = [:]
  private var chromeKey = ""
  private var hoverIndex: Int?
  private let names = ["notes", "browser", "guide", "wallpaper"]
  private let titles = ["Ghi chú", "Trình duyệt", "Bắt đầu", "Hình nền"]
  private let colors = [
    UIColor(red: 56/255, green: 100/255, blue: 222/255, alpha: 1),
    UIColor(red: 55/255, green: 138/255, blue: 142/255, alpha: 1),
    UIColor(red: 53/255, green: 134/255, blue: 119/255, alpha: 1),
    UIColor(red: 181/255, green: 121/255, blue: 96/255, alpha: 1),
  ]

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    backgroundColor = .clear
    taskbar.backgroundColor = .clear
    addSubview(taskbar)
    brand.text = "▥  SideScreen"
    brand.textColor = UIColor(red: 24/255, green: 49/255, blue: 63/255, alpha: 1)
    taskbar.addSubview(brand)
    arrange.tintColor = brand.textColor
    arrange.contentMode = .scaleAspectFit
    taskbar.addSubview(arrange)
    let symbols = ["square.and.pencil", "globe", "sparkles", "paintpalette"]
    for i in 0..<4 {
      let icon = UIImageView(image: UIImage(systemName: symbols[i]))
      icon.tintColor = .white
      icon.backgroundColor = colors[i]
      icon.contentMode = .center
      icon.clipsToBounds = true
      let label = UILabel()
      label.text = titles[i]
      label.textColor = brand.textColor
      label.textAlignment = .center
      let dot = UIView()
      dot.backgroundColor = colors[i]
      taskbar.addSubview(icon)
      taskbar.addSubview(label)
      taskbar.addSubview(dot)
      icons.append(icon)
      labels.append(label)
      indicators.append(dot)
    }
    configureCursor()
    addSubview(cursorView)
  }

  required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

  func apply(_ state: [String: Any]) {
    snapshot = state
    updateChrome()
    updateCursor()
  }

  func applyPointer(_ pointer: [String: Any]) {
    for key in ["cursorX", "cursorY"] {
      if let number = pointer[key] as? NSNumber, number.doubleValue.isFinite {
        snapshot[key] = number
      }
    }
    updateCursor()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateChrome()
    updateCursor()
  }

  private func number(_ key: String, fallback: CGFloat) -> CGFloat {
    guard let value = snapshot[key] as? NSNumber, value.doubleValue.isFinite else { return fallback }
    return CGFloat(value.doubleValue)
  }

  private var logicalWidth: CGFloat {
    snapshot["fullScreen"] as? Bool == false ? 1440 : 900 * min(4, max(0.6, number("displayAspect", fallback: 1.6)))
  }
  private var scale: CGFloat { min(bounds.width / logicalWidth, bounds.height / 900) }
  private var origin: CGPoint {
    CGPoint(x: (bounds.width - logicalWidth * scale) / 2, y: (bounds.height - 900 * scale) / 2)
  }
  private var dockUnit: CGFloat {
    min(900 / min(8640, max(320, number("viewportHeight", fallback: 900))), (logicalWidth - 16) / 320)
  }
  private var barLeft: CGFloat { (logicalWidth - 320 * dockUnit) / 2 }
  private var barTop: CGFloat { 900 - (min(96, max(4, number("safeInset", fallback: 8))) + 72) * dockUnit }

  private func updateChrome() {
    guard scale > 0 else { return }
    let windows = snapshot["windows"] as? [[String: Any]] ?? []
    let active = windows.last(where: { $0["minimized"] as? Bool != true })?["app"] as? String
    let running = Set(windows.compactMap { $0["app"] as? String })
    let key = "\(bounds.size)|\(logicalWidth)|\(barTop)|\(dockUnit)|\(running.sorted())|\(active ?? "")"
    guard key != chromeKey else { return }
    chromeKey = key
    let s = scale
    let unit = dockUnit * s
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    taskbar.frame = CGRect(x: origin.x + barLeft * s, y: origin.y + barTop * s, width: 320 * unit, height: 72 * unit)
    taskbar.layer.cornerRadius = 18 * unit
    brand.isHidden = true
    arrange.isHidden = true
    for i in 0..<4 {
      let x = 20 + CGFloat(i) * 72
      icons[i].transform = .identity
      icons[i].frame = CGRect(x: (x + 11) * unit, y: 11 * unit, width: 42 * unit, height: 42 * unit)
      icons[i].layer.cornerRadius = 13 * unit
      icons[i].preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28 * unit, weight: .medium)
      labels[i].frame = CGRect(x: (x + 32 - 50) * unit, y: -29 * unit, width: 100 * unit, height: 25 * unit)
      labels[i].font = .systemFont(ofSize: 10 * unit, weight: .medium)
      labels[i].textColor = .white
      labels[i].backgroundColor = UIColor(red: 24/255, green: 49/255, blue: 63/255, alpha: 1)
      labels[i].layer.cornerRadius = 7 * unit
      labels[i].clipsToBounds = true
      labels[i].isHidden = true
      indicators[i].isHidden = !running.contains(names[i])
      let width: CGFloat = active == names[i] ? 12 : 4
      indicators[i].frame = CGRect(x: (x + 32 - width / 2) * unit, y: 58 * unit, width: width * unit, height: 3 * unit)
      indicators[i].layer.cornerRadius = 1.5 * unit
    }
    hoverIndex = nil
    CATransaction.commit()
  }

  private func configureCursor() {
    cursorView.bounds = CGRect(x: 0, y: 0, width: 20, height: 24)
    cursorView.layer.anchorPoint = .zero
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 2, y: 1))
    path.addQuadCurve(to: CGPoint(x: 0.5, y: 3), controlPoint: CGPoint(x: 0.2, y: 0.2))
    path.addLine(to: CGPoint(x: 2, y: 19))
    path.addQuadCurve(to: CGPoint(x: 4, y: 19.5), controlPoint: CGPoint(x: 2.3, y: 21))
    path.addLine(to: CGPoint(x: 7.2, y: 16.5))
    path.addLine(to: CGPoint(x: 11, y: 22))
    path.addQuadCurve(to: CGPoint(x: 13.3, y: 22.5), controlPoint: CGPoint(x: 12, y: 23.4))
    path.addLine(to: CGPoint(x: 15, y: 21.3))
    path.addQuadCurve(to: CGPoint(x: 15.2, y: 19), controlPoint: CGPoint(x: 16.2, y: 20.5))
    path.addLine(to: CGPoint(x: 12, y: 14.5))
    path.addLine(to: CGPoint(x: 17, y: 14.2))
    path.addQuadCurve(to: CGPoint(x: 17.3, y: 12.4), controlPoint: CGPoint(x: 19.2, y: 14))
    path.close()
    let body = CAShapeLayer()
    body.path = path.cgPath
    body.fillColor = UIColor(red: 189/255, green: 233/255, blue: 220/255, alpha: 1).cgColor
    body.strokeColor = UIColor(red: 40/255, green: 81/255, blue: 77/255, alpha: 1).cgColor
    body.lineWidth = 1.05
    body.lineJoin = .round
    cursorView.layer.addSublayer(body)
    let eyes = CAShapeLayer()
    let face = UIBezierPath(ovalIn: CGRect(x: 4.95, y: 8.05, width: 1.5, height: 1.5))
    face.append(UIBezierPath(ovalIn: CGRect(x: 8.35, y: 9.45, width: 1.5, height: 1.5)))
    eyes.path = face.cgPath
    eyes.fillColor = body.strokeColor
    cursorView.layer.addSublayer(eyes)
    let smile = CAShapeLayer()
    let smilePath = UIBezierPath()
    smilePath.move(to: CGPoint(x: 5.8, y: 11.4))
    smilePath.addQuadCurve(to: CGPoint(x: 8.7, y: 12.7), controlPoint: CGPoint(x: 6.7, y: 13.4))
    smile.path = smilePath.cgPath
    smile.fillColor = UIColor.clear.cgColor
    smile.strokeColor = body.strokeColor
    smile.lineWidth = 0.8
    smile.lineCap = .round
    cursorView.layer.addSublayer(smile)
    cursorView.layer.shadowColor = UIColor.black.cgColor
    cursorView.layer.shadowOpacity = 0.13
    cursorView.layer.shadowRadius = 1
    cursorView.layer.shadowOffset = CGSize(width: 0, height: 1)
  }

  private func updateCursor() {
    guard scale > 0 else { return }
    let x = min(logicalWidth - 1, max(0, number("cursorX", fallback: 714)))
    let y = min(899, max(0, number("cursorY", fallback: 400)))
    let cursorScale = min(1.5, max(0.7, number("cursorScale", fallback: 1))) * scale
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    cursorView.layer.position = CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    cursorView.layer.setAffineTransform(CGAffineTransform(scaleX: cursorScale * 0.8, y: cursorScale * 20 / 24))
    CATransaction.commit()
    let index = (0..<4).first { i in
      CGRect(x: barLeft + (20 + CGFloat(i) * 72) * dockUnit, y: barTop + 8 * dockUnit, width: 64 * dockUnit, height: 56 * dockUnit).contains(CGPoint(x: x, y: y))
    }
    if index != hoverIndex {
      hoverIndex = index
      UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.12, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
        for i in 0..<4 {
          self.icons[i].transform = index == i ? CGAffineTransform(translationX: 0, y: -6 * self.scale * self.dockUnit).scaledBy(x: 1.18, y: 1.18) : .identity
          self.labels[i].isHidden = index != i
        }
      }
    }
  }
}
