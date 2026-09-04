import AppKit

@MainActor
protocol CodexActivityDetecting {
  func isCodexRunning() -> Bool
}

@MainActor
struct WorkspaceCodexActivityDetector: CodexActivityDetecting {
  func isCodexRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains { application in
      if application.bundleIdentifier?.lowercased() == "com.openai.codex" {
        return true
      }

      if application.localizedName?.lowercased() == "codex" {
        return true
      }

      return application.executableURL?.lastPathComponent.lowercased() == "codex"
    }
  }
}

enum RefreshIntervalPolicy {
  static func interval(
    isCodexRunning: Bool,
    runningMinutes: Int,
    idleMinutes: Int
  ) -> TimeInterval {
    let minutes = isCodexRunning ? runningMinutes : idleMinutes
    return TimeInterval(max(minutes, 1) * 60)
  }
}
