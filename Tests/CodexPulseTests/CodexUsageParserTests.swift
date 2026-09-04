import Foundation
import XCTest

@testable import CodexPulse

final class CodexUsageParserTests: XCTestCase {
  func testParsesFiveHourAndWeeklyWindows() throws {
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
            "used_percent": "36",
            "reset_at": 1789000000
          }
        }
      }
      """

    let snapshot = try CodexUsageParser.parse(Data(payload.utf8))

    XCTAssertEqual(snapshot.fiveHourRemainingPercent, 72)
    XCTAssertEqual(snapshot.weeklyRemainingPercent, 64)
    XCTAssertEqual(snapshot.fiveHourResetAt.timeIntervalSince1970, 1_788_509_000)
  }

  func testRejectsPayloadWithoutFiveHourWindow() {
    let payload = """
      {
        "rate_limit": {
          "primary_window": {
            "limit_window_seconds": 604800,
            "used_percent": 20,
            "reset_at": 1789000000
          }
        }
      }
      """

    XCTAssertThrowsError(try CodexUsageParser.parse(Data(payload.utf8))) { error in
      guard let providerError = error as? CodexQuotaProviderError,
        case .missingFiveHourWindow = providerError
      else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
  }
}
