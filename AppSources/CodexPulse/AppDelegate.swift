import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let settings = SettingsStore.shared
  private let touchBarController = TouchBarController()
  private lazy var refreshCoordinator = RefreshCoordinator(
    provider: CodexQuotaProvider(),
    activityDetector: WorkspaceCodexActivityDetector(),
    settings: settings
  )
  private lazy var settingsWindowController = SettingsWindowController(settings: settings)

  private var statusItem: NSStatusItem?
  private var settingsObserver: NSObjectProtocol?
  private var latestSnapshot: QuotaSnapshot?

  private let fiveHourItem = NSMenuItem(title: "5H Capacity    --", action: nil, keyEquivalent: "")
  private let resetItem = NSMenuItem(title: "Reset    --", action: nil, keyEquivalent: "")
  private let weeklyItem = NSMenuItem(title: "Weekly    --", action: nil, keyEquivalent: "")

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    updateMenuBarVisibility()
    touchBarController.setEnabled(settings.showTouchBarStatus)
    touchBarController.onRefresh = { [weak self] in
      self?.refreshCoordinator.refreshNow()
    }

    refreshCoordinator.onSnapshot = { [weak self] snapshot in
      self?.apply(snapshot)
    }
    refreshCoordinator.onFailure = { [weak self] in
      self?.applyUnavailableState()
    }

    settingsObserver = NotificationCenter.default.addObserver(
      forName: .codexPulseSettingsDidChange,
      object: settings,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.updateMenuBarVisibility()
        self?.touchBarController.setEnabled(self?.settings.showTouchBarStatus ?? false)
      }
    }

    refreshCoordinator.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    refreshCoordinator.stop()
    touchBarController.unregister()
    if let settingsObserver {
      NotificationCenter.default.removeObserver(settingsObserver)
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    if !settings.showMenuBarIcon {
      showSettings()
    }
    return true
  }

  func menuWillOpen(_ menu: NSMenu) {
    refreshCoordinator.refreshNow()
  }

  private func updateMenuBarVisibility() {
    if settings.showMenuBarIcon {
      if statusItem == nil {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.menu = makeMenu()
        item.button?.toolTip = "Codex Pulse"
        statusItem = item
      }
      updateStatusIcon()
    } else if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self

    let title = NSMenuItem(title: "Codex Pulse", action: nil, keyEquivalent: "")
    title.isEnabled = false
    fiveHourItem.isEnabled = false
    resetItem.isEnabled = false
    weeklyItem.isEnabled = false

    menu.addItem(title)
    menu.addItem(.separator())
    menu.addItem(fiveHourItem)
    menu.addItem(resetItem)
    menu.addItem(weeklyItem)
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Refresh Now",
        action: #selector(refreshNow),
        keyEquivalent: "r"
      ))
    menu.addItem(
      NSMenuItem(
        title: "Settings…",
        action: #selector(showSettings),
        keyEquivalent: ","
      ))
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit Codex Pulse",
        action: #selector(quit),
        keyEquivalent: "q"
      ))

    for item in menu.items {
      if item.action != nil {
        item.target = self
      }
    }
    return menu
  }

  private func apply(_ snapshot: QuotaSnapshot) {
    latestSnapshot = snapshot
    fiveHourItem.title = "5H Capacity    \(snapshot.fiveHourRemainingPercent)%"
    resetItem.title =
      "Reset    \(snapshot.fiveHourResetAt.formatted(date: .omitted, time: .shortened))"
    weeklyItem.title = "Weekly    \(snapshot.weeklyRemainingPercent)%"
    touchBarController.update(remainingPercent: snapshot.fiveHourRemainingPercent)
    updateStatusIcon()
  }

  private func applyUnavailableState() {
    latestSnapshot = nil
    fiveHourItem.title = "5H Capacity    --"
    resetItem.title = "Reset    --"
    weeklyItem.title = "Weekly    --"
    touchBarController.update(remainingPercent: nil)
    updateStatusIcon()
  }

  private func updateStatusIcon() {
    guard let button = statusItem?.button else { return }
    let level = QuotaLevel(remainingPercent: latestSnapshot?.fiveHourRemainingPercent)
    button.attributedTitle = NSAttributedString(
      string: "●",
      attributes: [
        .foregroundColor: level.color,
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
      ]
    )
    button.setAccessibilityLabel("Codex Pulse")
    button.setAccessibilityValue(
      latestSnapshot.map { "5 hour capacity \($0.fiveHourRemainingPercent) percent" }
        ?? "Capacity unavailable")
  }

  @objc private func refreshNow() {
    refreshCoordinator.refreshNow()
  }

  @objc private func showSettings() {
    settingsWindowController.showWindow(nil)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
