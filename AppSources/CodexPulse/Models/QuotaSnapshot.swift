import AppKit
import Foundation

struct QuotaSnapshot: Equatable, Sendable {
  let fiveHourRemainingPercent: Int
  let weeklyRemainingPercent: Int
  let fiveHourResetAt: Date

  init(
    fiveHourRemainingPercent: Int,
    weeklyRemainingPercent: Int,
    fiveHourResetAt: Date
  ) {
    self.fiveHourRemainingPercent = min(max(fiveHourRemainingPercent, 0), 100)
    self.weeklyRemainingPercent = min(max(weeklyRemainingPercent, 0), 100)
    self.fiveHourResetAt = fiveHourResetAt
  }
}

enum QuotaLevel: Equatable {
  case normal
  case warning
  case critical
  case unavailable

  init(remainingPercent: Int?) {
    guard let remainingPercent else {
      self = .unavailable
      return
    }

    switch remainingPercent {
    case 31...:
      self = .normal
    case 11...30:
      self = .warning
    default:
      self = .critical
    }
  }

  @MainActor
  var color: NSColor {
    switch self {
    case .normal:
      return .systemGreen
    case .warning:
      return .systemOrange
    case .critical:
      return .systemRed
    case .unavailable:
      return .secondaryLabelColor
    }
  }
}
