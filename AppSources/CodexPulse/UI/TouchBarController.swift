import AppKit
import Darwin

private extension NSTouchBarItem.Identifier {
  static let codexPulseStatus = NSTouchBarItem.Identifier("com.codexpulse.status")
  static let codexPulseSystemTray = NSTouchBarItem.Identifier("com.codexpulse.system-tray.v2")
}

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
  var onRefresh: (() -> Void)?

  private static let trayIdentifier = "com.codexpulse.system-tray.v2"
  private let statusButton = NSButton(title: "CX --", target: nil, action: nil)
  private let statusItem = NSCustomTouchBarItem(identifier: .codexPulseStatus)
  private let systemTrayItem = NSCustomTouchBarItem(identifier: .codexPulseSystemTray)
  private let systemTrayButton = NSButton(title: "CX --", target: nil, action: nil)
  private var isSystemTrayRegistered = false
  private var visibilityTimer: Timer?

  private lazy var touchBar: NSTouchBar = {
    let touchBar = NSTouchBar()
    touchBar.delegate = self
    touchBar.defaultItemIdentifiers = [.codexPulseStatus]
    touchBar.principalItemIdentifier = .codexPulseStatus
    touchBar.templateItems = [statusItem]
    return touchBar
  }()

  override init() {
    super.init()
    configure(button: statusButton, action: #selector(refreshClicked))
    statusButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
    statusItem.view = statusButton
    statusItem.customizationLabel = "Codex 5H Capacity"

    configure(button: systemTrayButton, action: #selector(systemTrayClicked))
    systemTrayItem.view = systemTrayButton
    systemTrayItem.customizationLabel = "Codex 5H Capacity"
  }

  func setEnabled(_ enabled: Bool) {
    if enabled {
      registerSystemTrayItemIfNeeded()
      NSApp.touchBar = touchBar
      presentSystemTouchBar()
      startVisibilityTimer()
    } else {
      unregister()
      NSApp.touchBar = nil
    }
  }

  func unregister() {
    visibilityTimer?.invalidate()
    visibilityTimer = nil

    guard isSystemTrayRegistered else { return }

    setControlStripPresence(false)

    let itemClass = NSTouchBarItem.self as AnyObject
    let removeSelector = NSSelectorFromString("removeSystemTrayItem:")
    if itemClass.responds(to: removeSelector) {
      _ = itemClass.perform(removeSelector, with: systemTrayItem)
    }

    let touchBarClass = NSTouchBar.self as AnyObject
    let dismissSelector = NSSelectorFromString("dismissSystemModalTouchBar:")
    if touchBarClass.responds(to: dismissSelector) {
      _ = touchBarClass.perform(dismissSelector, with: touchBar)
    }

    isSystemTrayRegistered = false
  }

  func update(remainingPercent: Int?) {
    let title = remainingPercent.map { "CX \($0)%" } ?? "CX --"
    let color = QuotaLevel(remainingPercent: remainingPercent).color

    statusButton.title = title
    statusButton.bezelColor = color
    systemTrayButton.title = title
    systemTrayButton.bezelColor = color
  }

  func touchBar(
    _ touchBar: NSTouchBar,
    makeItemForIdentifier identifier: NSTouchBarItem.Identifier
  ) -> NSTouchBarItem? {
    guard identifier == .codexPulseStatus else { return nil }
    let item = NSCustomTouchBarItem(identifier: identifier)
    item.view = statusButton
    item.customizationLabel = "Codex 5H Capacity"
    return item
  }

  private func configure(button: NSButton, action: Selector) {
    button.target = self
    button.action = action
    button.bezelStyle = .rounded
    button.bezelColor = QuotaLevel.unavailable.color
    button.contentTintColor = .white
    button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    button.setAccessibilityLabel("Codex 5 hour capacity")
  }

  private func registerSystemTrayItemIfNeeded() {
    if isSystemTrayRegistered {
      setControlStripPresence(true)
      return
    }

    let itemClass = NSTouchBarItem.self as AnyObject
    let addSelector = NSSelectorFromString("addSystemTrayItem:")
    guard itemClass.responds(to: addSelector) else { return }

    _ = itemClass.perform(addSelector, with: systemTrayItem)
    setControlStripPresence(true)
    isSystemTrayRegistered = true
  }

  private func presentSystemTouchBar() {
    let touchBarClass = NSTouchBar.self as AnyObject
    let selector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
    guard touchBarClass.responds(to: selector) else { return }

    _ = touchBarClass.perform(
      selector,
      with: touchBar,
      with: nil
    )
  }

  private func startVisibilityTimer() {
    guard visibilityTimer == nil else { return }

    let timer = Timer.scheduledTimer(
      timeInterval: 8,
      target: self,
      selector: #selector(restoreVisibility),
      userInfo: nil,
      repeats: true
    )
    timer.tolerance = 2
    visibilityTimer = timer
  }

  private func setControlStripPresence(_ present: Bool) {
    typealias PresenceFunction = @convention(c) (CFString, Bool) -> Void
    guard
      let symbol = dlsym(
        UnsafeMutableRawPointer(bitPattern: -2),
        "DFRElementSetControlStripPresenceForIdentifier"
      )
    else { return }

    let function = unsafeBitCast(symbol, to: PresenceFunction.self)
    function(Self.trayIdentifier as CFString, present)
  }

  @objc private func refreshClicked() {
    onRefresh?()
  }

  @objc private func systemTrayClicked() {
    onRefresh?()
    presentSystemTouchBar()
  }

  @objc private func restoreVisibility() {
    guard isSystemTrayRegistered else { return }
    presentSystemTouchBar()
  }
}
