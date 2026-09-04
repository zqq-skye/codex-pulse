import AppKit
import Foundation

@MainActor
final class RefreshCoordinator: NSObject {
  var onSnapshot: ((QuotaSnapshot) -> Void)?
  var onFailure: (() -> Void)?

  private let provider: any QuotaProvider
  private let activityDetector: any CodexActivityDetecting
  private let settings: SettingsStore
  private var timer: Timer?
  private var refreshTask: Task<Void, Never>?
  private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

  init(
    provider: any QuotaProvider,
    activityDetector: any CodexActivityDetecting,
    settings: SettingsStore
  ) {
    self.provider = provider
    self.activityDetector = activityDetector
    self.settings = settings
    super.init()
  }

  func start() {
    let center = NotificationCenter.default
    observers.append(
      (
        center,
        center.addObserver(
          forName: .codexPulseSettingsDidChange,
          object: settings,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.scheduleNextRefresh() }
        }
      ))

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    observers.append(
      (
        workspaceCenter,
        workspaceCenter.addObserver(
          forName: NSWorkspace.didWakeNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.refreshNow() }
        }
      ))
    observers.append(
      (
        workspaceCenter,
        workspaceCenter.addObserver(
          forName: NSWorkspace.didLaunchApplicationNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.scheduleNextRefresh() }
        }
      ))
    observers.append(
      (
        workspaceCenter,
        workspaceCenter.addObserver(
          forName: NSWorkspace.didTerminateApplicationNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.scheduleNextRefresh() }
        }
      ))

    refreshNow()
  }

  func refreshNow() {
    timer?.invalidate()
    refreshTask?.cancel()

    let provider = self.provider
    refreshTask = Task { @MainActor [weak self] in
      guard let self else { return }

      do {
        let snapshot = try await provider.fetchQuota()
        guard !Task.isCancelled else { return }
        onSnapshot?(snapshot)
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled else { return }
        onFailure?()
      }

      scheduleNextRefresh()
    }
  }

  func stop() {
    timer?.invalidate()
    refreshTask?.cancel()
    for observer in observers {
      observer.center.removeObserver(observer.token)
    }
    observers.removeAll()
  }

  private func scheduleNextRefresh() {
    timer?.invalidate()

    let interval = RefreshIntervalPolicy.interval(
      isCodexRunning: activityDetector.isCodexRunning(),
      runningMinutes: settings.runningRefreshMinutes,
      idleMinutes: settings.idleRefreshMinutes
    )

    let timer = Timer(
      timeInterval: interval,
      target: self,
      selector: #selector(timerDidFire),
      userInfo: nil,
      repeats: false
    )
    timer.tolerance = min(interval * 0.1, 60)
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  @objc private func timerDidFire() {
    refreshNow()
  }
}
