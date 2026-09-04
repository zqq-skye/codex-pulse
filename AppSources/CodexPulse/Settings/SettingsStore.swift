import Foundation

extension Notification.Name {
  static let codexPulseSettingsDidChange = Notification.Name("CodexPulseSettingsDidChange")
}

@MainActor
final class SettingsStore {
  static let shared = SettingsStore()

  private enum Key {
    static let launchAtLogin = "launchAtLogin"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showTouchBarStatus = "showTouchBarStatus"
    static let runningRefreshMinutes = "runningRefreshMinutes"
    static let idleRefreshMinutes = "idleRefreshMinutes"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.launchAtLogin: false,
      Key.showMenuBarIcon: true,
      Key.showTouchBarStatus: true,
      Key.runningRefreshMinutes: 5,
      Key.idleRefreshMinutes: 20,
    ])
  }

  var launchAtLogin: Bool {
    get { defaults.bool(forKey: Key.launchAtLogin) }
    set { set(newValue, forKey: Key.launchAtLogin) }
  }

  var showMenuBarIcon: Bool {
    get { defaults.bool(forKey: Key.showMenuBarIcon) }
    set { set(newValue, forKey: Key.showMenuBarIcon) }
  }

  var showTouchBarStatus: Bool {
    get { defaults.bool(forKey: Key.showTouchBarStatus) }
    set { set(newValue, forKey: Key.showTouchBarStatus) }
  }

  var runningRefreshMinutes: Int {
    get { max(defaults.integer(forKey: Key.runningRefreshMinutes), 1) }
    set { set(max(newValue, 1), forKey: Key.runningRefreshMinutes) }
  }

  var idleRefreshMinutes: Int {
    get { max(defaults.integer(forKey: Key.idleRefreshMinutes), 1) }
    set { set(max(newValue, 1), forKey: Key.idleRefreshMinutes) }
  }

  private func set(_ value: Any, forKey key: String) {
    defaults.set(value, forKey: key)
    NotificationCenter.default.post(name: .codexPulseSettingsDidChange, object: self)
  }
}
