import CFNetwork
import Foundation

protocol QuotaProvider: Sendable {
  func fetchQuota() async throws -> QuotaSnapshot
}

enum CodexQuotaProviderError: LocalizedError {
  case missingAuthentication
  case requestFailed(String)
  case invalidResponse
  case missingFiveHourWindow
  case missingWeeklyWindow

  var errorDescription: String? {
    switch self {
    case .missingAuthentication:
      return "没有找到 Codex 登录状态"
    case .requestFailed(let message):
      return message.isEmpty ? "无法连接官方用量服务" : message
    case .invalidResponse:
      return "官方用量数据格式无法识别"
    case .missingFiveHourWindow:
      return "官方暂未返回 5 小时额度窗口"
    case .missingWeeklyWindow:
      return "官方暂未返回当周额度窗口"
    }
  }
}

/// 从本机 Codex 登录状态读取官方用量。凭据只通过 curl 标准输入传递，
/// 不写入磁盘，也不会发送到第三方服务。
struct CodexQuotaProvider: QuotaProvider {
  private let authFileURL: URL

  init(
    authFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex/auth.json")
  ) {
    self.authFileURL = authFileURL
  }

  func fetchQuota() async throws -> QuotaSnapshot {
    let authData = try Data(contentsOf: authFileURL)
    let authObject = try JSONSerialization.jsonObject(with: authData)
    guard
      let auth = authObject as? [String: Any],
      let tokens = auth["tokens"] as? [String: Any],
      let accessToken = tokens["access_token"] as? String,
      !accessToken.isEmpty,
      let accountID = tokens["account_id"] as? String,
      !accountID.isEmpty
    else {
      throw CodexQuotaProviderError.missingAuthentication
    }

    var config = """
      silent
      show-error
      max-time = 20
      url = "https://chatgpt.com/backend-api/wham/usage"
      header = "Authorization: Bearer \(escapeForCurlConfig(accessToken))"
      header = "ChatGPT-Account-ID: \(escapeForCurlConfig(accountID))"

      """
    if let proxyURL = configuredSystemHTTPSProxyURL() {
      config = "proxy = \"\(escapeForCurlConfig(proxyURL))\"\n" + config
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    process.arguments = ["--config", "-"]

    let input = Pipe()
    let output = Pipe()
    let errorOutput = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = errorOutput

    try process.run()
    input.fileHandleForWriting.write(Data(config.utf8))
    try? input.fileHandleForWriting.close()

    let responseData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let message =
        String(data: errorData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      throw CodexQuotaProviderError.requestFailed(message)
    }

    return try CodexUsageParser.parse(responseData)
  }

  private func configuredSystemHTTPSProxyURL() -> String? {
    guard
      let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
        as? [String: Any],
      (proxySettings[kCFNetworkProxiesHTTPSEnable as String] as? NSNumber)?.boolValue == true,
      let host = proxySettings[kCFNetworkProxiesHTTPSProxy as String] as? String,
      !host.isEmpty,
      let port = (proxySettings[kCFNetworkProxiesHTTPSPort as String] as? NSNumber)?.intValue,
      (1...65_535).contains(port)
    else {
      return nil
    }

    var components = URLComponents()
    components.scheme = "http"
    components.host = host
    components.port = port
    return components.url?.absoluteString
  }

  private func escapeForCurlConfig(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "")
      .replacingOccurrences(of: "\r", with: "")
  }
}

enum CodexUsageParser {
  private static let fiveHourWindowSeconds = 5.0 * 60 * 60
  private static let weeklyWindowSeconds = 7.0 * 24 * 60 * 60

  static func parse(_ data: Data) throws -> QuotaSnapshot {
    guard
      let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let rateLimit = payload["rate_limit"] as? [String: Any]
    else {
      throw CodexQuotaProviderError.invalidResponse
    }

    let windows = ["primary_window", "secondary_window"]
      .compactMap { rateLimit[$0] as? [String: Any] }

    guard
      let fiveHour = closestWindow(
        in: windows,
        targetSeconds: fiveHourWindowSeconds,
        allowedRange: (4 * 60 * 60)...(6 * 60 * 60)
      )
    else {
      throw CodexQuotaProviderError.missingFiveHourWindow
    }

    guard
      let weekly = closestWindow(
        in: windows,
        targetSeconds: weeklyWindowSeconds,
        allowedRange: (5 * 24 * 60 * 60)...(9 * 24 * 60 * 60)
      )
    else {
      throw CodexQuotaProviderError.missingWeeklyWindow
    }

    guard
      let fiveHourUsed = number(fiveHour["used_percent"]),
      let weeklyUsed = number(weekly["used_percent"]),
      let resetAt = number(fiveHour["reset_at"])
    else {
      throw CodexQuotaProviderError.invalidResponse
    }

    return QuotaSnapshot(
      fiveHourRemainingPercent: remainingPercent(fromUsed: fiveHourUsed),
      weeklyRemainingPercent: remainingPercent(fromUsed: weeklyUsed),
      fiveHourResetAt: Date(timeIntervalSince1970: resetAt)
    )
  }

  private static func closestWindow(
    in windows: [[String: Any]],
    targetSeconds: Double,
    allowedRange: ClosedRange<Double>
  ) -> [String: Any]? {
    windows
      .filter { window in
        guard let seconds = number(window["limit_window_seconds"]) else { return false }
        return allowedRange.contains(seconds)
      }
      .min { left, right in
        let leftDistance = abs((number(left["limit_window_seconds"]) ?? 0) - targetSeconds)
        let rightDistance = abs((number(right["limit_window_seconds"]) ?? 0) - targetSeconds)
        return leftDistance < rightDistance
      }
  }

  private static func number(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    if let string = value as? String {
      return Double(string)
    }
    return nil
  }

  private static func remainingPercent(fromUsed usedPercent: Double) -> Int {
    Int(min(max(100 - usedPercent, 0), 100).rounded())
  }
}

/// 无网络的预览和测试数据源。
struct MockQuotaProvider: QuotaProvider {
  private let snapshot: QuotaSnapshot

  init(now: Date = Date()) {
    snapshot = QuotaSnapshot(
      fiveHourRemainingPercent: 72,
      weeklyRemainingPercent: 64,
      fiveHourResetAt: now.addingTimeInterval(90 * 60)
    )
  }

  func fetchQuota() async throws -> QuotaSnapshot {
    snapshot
  }
}
