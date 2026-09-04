import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
    exit(EXIT_FAILURE)
  }
}

expect(QuotaLevel(remainingPercent: 31) == .normal, "31% should be normal")
expect(QuotaLevel(remainingPercent: 30) == .warning, "30% should be warning")
expect(QuotaLevel(remainingPercent: 11) == .warning, "11% should be warning")
expect(QuotaLevel(remainingPercent: 10) == .critical, "10% should be critical")

expect(
  RefreshIntervalPolicy.interval(isCodexRunning: true, runningMinutes: 5, idleMinutes: 20)
    == 300,
  "running interval should be 5 minutes")
expect(
  RefreshIntervalPolicy.interval(isCodexRunning: false, runningMinutes: 5, idleMinutes: 20)
    == 1_200,
  "idle interval should be 20 minutes")

let payload = """
  {
    "rate_limit": {
      "primary_window": {
        "limit_window_seconds": 18000,
        "used_percent": 28.4,
        "reset_at": 1788509000
      },
      "secondary_window": {
        "limit_window_seconds": 604800,
        "used_percent": 62,
        "reset_at": 1789000000
      }
    }
  }
  """

do {
  let snapshot = try CodexUsageParser.parse(Data(payload.utf8))
  expect(snapshot.fiveHourRemainingPercent == 72, "5H remaining should be 72%")
  expect(snapshot.weeklyRemainingPercent == 38, "weekly remaining should be 38%")
} catch {
  FileHandle.standardError.write(Data("FAILED: parser threw \(error)\n".utf8))
  exit(EXIT_FAILURE)
}

print("smoke-tests-ok")
