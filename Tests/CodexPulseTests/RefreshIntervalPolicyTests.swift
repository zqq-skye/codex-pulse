import XCTest

@testable import CodexPulse

final class RefreshIntervalPolicyTests: XCTestCase {
  func testUsesFiveMinutesWhileCodexIsRunning() {
    XCTAssertEqual(
      RefreshIntervalPolicy.interval(
        isCodexRunning: true,
        runningMinutes: 5,
        idleMinutes: 20
      ),
      300
    )
  }

  func testUsesTwentyMinutesWhileCodexIsNotRunning() {
    XCTAssertEqual(
      RefreshIntervalPolicy.interval(
        isCodexRunning: false,
        runningMinutes: 5,
        idleMinutes: 20
      ),
      1_200
    )
  }

  func testNeverSchedulesBelowOneMinute() {
    XCTAssertEqual(
      RefreshIntervalPolicy.interval(
        isCodexRunning: true,
        runningMinutes: 0,
        idleMinutes: 20
      ),
      60
    )
  }
}
