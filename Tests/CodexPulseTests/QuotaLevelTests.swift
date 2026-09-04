import XCTest

@testable import CodexPulse

final class QuotaLevelTests: XCTestCase {
  func testQuotaLevelBoundaries() {
    XCTAssertEqual(QuotaLevel(remainingPercent: 100), .normal)
    XCTAssertEqual(QuotaLevel(remainingPercent: 31), .normal)
    XCTAssertEqual(QuotaLevel(remainingPercent: 30), .warning)
    XCTAssertEqual(QuotaLevel(remainingPercent: 11), .warning)
    XCTAssertEqual(QuotaLevel(remainingPercent: 10), .critical)
    XCTAssertEqual(QuotaLevel(remainingPercent: 0), .critical)
    XCTAssertEqual(QuotaLevel(remainingPercent: nil), .unavailable)
  }

  func testSnapshotClampsPercentages() {
    let snapshot = QuotaSnapshot(
      fiveHourRemainingPercent: 140,
      weeklyRemainingPercent: -20,
      fiveHourResetAt: .distantFuture
    )

    XCTAssertEqual(snapshot.fiveHourRemainingPercent, 100)
    XCTAssertEqual(snapshot.weeklyRemainingPercent, 0)
  }
}
