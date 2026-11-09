import UIKit
import WebKit

/// Places the plugin-owned WKWebView in external-screen points. Flutter's iOS
/// platform-view compositor currently divides frames by UIScreen.main.scale,
/// which can be 3 on the phone while the attached display uses scale 1.
final class ExternalBrowserWindow: UIWindow {
  let browserHost = ExternalBrowserHost(frame: .zero)

  func installBrowserHost() {
    windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    if rootViewController == nil {
      let controller = UIViewController()
      controller.view.backgroundColor = .clear
      rootViewController = controller
    }
    if browserHost.superview !== self { addSubview(browserHost) }
    if browserHost.frame != bounds { browserHost.frame = bounds }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    installBrowserHost()
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

final class ExternalBrowserHost: UIView {
  let content = UIView()
  private let progressView = UIProgressView(progressViewStyle: .bar)
  private(set) var webView: WKWebView?
  private(set) var identifier: Int64?
  private var snapshot: [String: Any] = [:]
  private var requestedVisible = true

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    isHidden = true
    content.clipsToBounds = true
    addSubview(content)
    progressView.progressTintColor = UIColor(red: 56/255, green: 100/255, blue: 222/255, alpha: 1)
    progressView.trackTintColor = .clear
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func attach(_ next: WKWebView, identifier nextIdentifier: Int64) {
    if webView !== next {
      detach()
      next.removeFromSuperview()
      webView = next
      identifier = nextIdentifier
      next.translatesAutoresizingMaskIntoConstraints = true
      next.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      next.scrollView.contentInsetAdjustmentBehavior = .never
      content.addSubview(next)
      content.addSubview(progressView)
    }
    requestedVisible = true
    progressView.progress = 0
    progressView.isHidden = false
    layoutBrowser()
  }

  func detach(identifier expected: Int64? = nil) {
    if let expected = expected, expected != identifier { return }
    webView?.stopLoading()
    webView?.removeFromSuperview()
    webView = nil
    identifier = nil
    isHidden = true
  }

  func present(identifier expected: Int64, visible: Bool, progress: Int) {
    guard expected == identifier else { return }
    requestedVisible = visible
    progressView.progress = Float(min(100, max(0, progress))) / 100
    progressView.isHidden = progress >= 100 || !visible
    layoutBrowser()
  }

  func apply(_ state: [String: Any]) {
    snapshot = state
    layoutBrowser()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layoutBrowser()
  }

  /// All rectangles come from the same domain geometry used by the cursor.
  /// No phone screen scale or device pixel ratio participates in this mapping.
  private func layoutBrowser() {
    guard webView != nil, requestedVisible,
          bounds.width > 0, bounds.height > 0,
          let viewport = snapshot["browserViewport"] as? [String: Any],
          let rawFrame = viewport["frame"] as? [String: Any],
          let logicalFrame = Self.rect(rawFrame),
          let rawRegions = viewport["visibleRegions"] as? [[String: Any]] else {
      isHidden = true
      return
    }
    let regions = rawRegions.compactMap(Self.rect)
    guard !regions.isEmpty else { isHidden = true; return }
    let aspect = (snapshot["displayAspect"] as? NSNumber)?.doubleValue ?? 1.6
    let width: CGFloat = snapshot["fullScreen"] as? Bool == false
      ? 1440 : 900 * CGFloat(min(4, max(0.6, aspect.isFinite ? aspect : 1.6)))
    let scale = min(bounds.width / width, bounds.height / 900)
    let origin = CGPoint(x: (bounds.width - width * scale) / 2, y: (bounds.height - 900 * scale) / 2)
    let frame = CGRect(x: origin.x + logicalFrame.minX * scale,
                       y: origin.y + logicalFrame.minY * scale,
                       width: logicalFrame.width * scale, height: logicalFrame.height * scale)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if content.frame != frame { content.frame = frame }
    if webView?.frame != content.bounds { webView?.frame = content.bounds }
    progressView.frame = CGRect(x: 0, y: 0, width: content.bounds.width, height: 2)
    // Regions are already disjoint, including overlapping foreground windows.
    let path = UIBezierPath()
    for region in regions {
      let local = CGRect(x: (region.minX - logicalFrame.minX) * scale,
                         y: (region.minY - logicalFrame.minY) * scale,
                         width: region.width * scale, height: region.height * scale)
        .intersection(content.bounds)
      if !local.isNull && !local.isEmpty { path.append(UIBezierPath(rect: local)) }
    }
    let mask = CAShapeLayer()
    mask.frame = content.bounds
    mask.path = path.cgPath
    mask.fillColor = UIColor.black.cgColor
    content.layer.mask = mask
    isHidden = false
    CATransaction.commit()
  }

  private static func rect(_ raw: [String: Any]) -> CGRect? {
    guard let x = raw["x"] as? NSNumber, let y = raw["y"] as? NSNumber,
          let width = raw["width"] as? NSNumber, let height = raw["height"] as? NSNumber,
          [x, y, width, height].allSatisfy({ $0.doubleValue.isFinite }),
          width.doubleValue > 0, height.doubleValue > 0 else { return nil }
    return CGRect(x: x.doubleValue, y: y.doubleValue, width: width.doubleValue, height: height.doubleValue)
  }
}
