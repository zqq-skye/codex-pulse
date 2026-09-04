import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
  private let settings: SettingsStore
  private let launchAtLoginController = LaunchAtLoginController()

  private lazy var launchAtLoginButton = checkbox(
    "Launch at Login", action: #selector(toggleLaunchAtLogin))
  private lazy var menuBarButton = checkbox("Show Menu Bar Icon", action: #selector(toggleMenuBar))
  private lazy var touchBarButton = checkbox(
    "Show Touch Bar Status", action: #selector(toggleTouchBar))
  private lazy var runningField = numberField(action: #selector(refreshValueChanged))
  private lazy var idleField = numberField(action: #selector(refreshValueChanged))
  private let loginStatusLabel = NSTextField(labelWithString: "")

  init(settings: SettingsStore) {
    self.settings = settings

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Codex Pulse Settings"
    window.isReleasedWhenClosed = false
    super.init(window: window)

    buildContent()
    reloadValues()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func showWindow(_ sender: Any?) {
    reloadValues()
    super.showWindow(sender)
    window?.center()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(sender)
  }

  private func buildContent() {
    guard let contentView = window?.contentView else { return }

    let generalTitle = sectionTitle("General")
    let refreshTitle = sectionTitle("Refresh")
    let runningRow = refreshRow(label: "Codex running", field: runningField)
    let idleRow = refreshRow(label: "Codex not running", field: idleField)

    loginStatusLabel.textColor = .systemRed
    loginStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    loginStatusLabel.maximumNumberOfLines = 2
    loginStatusLabel.isHidden = true

    let stack = NSStackView(views: [
      generalTitle,
      launchAtLoginButton,
      menuBarButton,
      touchBarButton,
      loginStatusLabel,
      refreshTitle,
      runningRow,
      idleRow,
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
    ])
  }

  private func checkbox(_ title: String, action: Selector) -> NSButton {
    NSButton(checkboxWithTitle: title, target: self, action: action)
  }

  private func sectionTitle(_ title: String) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    return label
  }

  private func numberField(action: Selector) -> NSTextField {
    let field = NSTextField()
    field.alignment = .right
    field.target = self
    field.action = action
    field.formatter = NumberFormatter.positiveInteger
    field.widthAnchor.constraint(equalToConstant: 48).isActive = true
    return field
  }

  private func refreshRow(label: String, field: NSTextField) -> NSView {
    let title = NSTextField(labelWithString: label)
    title.widthAnchor.constraint(equalToConstant: 150).isActive = true
    let unit = NSTextField(labelWithString: "min")
    let row = NSStackView(views: [title, field, unit])
    row.orientation = .horizontal
    row.spacing = 8
    return row
  }

  private func reloadValues() {
    launchAtLoginButton.state = launchAtLoginController.isEnabled ? .on : .off
    settings.launchAtLogin = launchAtLoginController.isEnabled
    menuBarButton.state = settings.showMenuBarIcon ? .on : .off
    touchBarButton.state = settings.showTouchBarStatus ? .on : .off
    runningField.integerValue = settings.runningRefreshMinutes
    idleField.integerValue = settings.idleRefreshMinutes
  }

  @objc private func toggleLaunchAtLogin() {
    let requestedValue = launchAtLoginButton.state == .on
    do {
      try launchAtLoginController.setEnabled(requestedValue)
      settings.launchAtLogin = requestedValue
      loginStatusLabel.isHidden = true
    } catch {
      launchAtLoginButton.state = launchAtLoginController.isEnabled ? .on : .off
      settings.launchAtLogin = launchAtLoginController.isEnabled
      loginStatusLabel.stringValue =
        "Launch at Login requires running the packaged app from Applications."
      loginStatusLabel.isHidden = false
    }
  }

  @objc private func toggleMenuBar() {
    settings.showMenuBarIcon = menuBarButton.state == .on
  }

  @objc private func toggleTouchBar() {
    settings.showTouchBarStatus = touchBarButton.state == .on
  }

  @objc private func refreshValueChanged() {
    settings.runningRefreshMinutes = max(runningField.integerValue, 1)
    settings.idleRefreshMinutes = max(idleField.integerValue, 1)
    reloadValues()
  }
}

extension NumberFormatter {
  fileprivate static var positiveInteger: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    formatter.minimum = 1
    formatter.maximum = 1_440
    formatter.allowsFloats = false
    return formatter
  }
}
