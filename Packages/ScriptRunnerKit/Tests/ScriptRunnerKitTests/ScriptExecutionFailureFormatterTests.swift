import XCTest
@testable import ScriptRunnerKit

final class ScriptExecutionFailureFormatterTests: XCTestCase {
  func testDetailedFailureIncludesLogicalNameDurationAndStructuredError() {
    let startedAt = Date(timeIntervalSince1970: 100)
    let result = ScriptExecutionResult(
      requestID: UUID(),
      status: .compileError,
      sourceResultDescription: nil,
      rawResultDescription: nil,
      errorNumber: -2741,
      errorMessage: "Expected expression but found end of script.",
      errorBriefMessage: nil,
      errorRange: ScriptSourceRange(location: 12, length: 1),
      executionDuration: 1.25,
      startedAt: startedAt,
      completedAt: startedAt.addingTimeInterval(1.25)
    )

    let description = ScriptExecutionFailureFormatter().string(
      from: result,
      identity: ScriptExecutionIdentity(displayName: "Stored Command")
    )

    XCTAssertTrue(description.contains("Script: Stored Command"))
    XCTAssertTrue(description.contains("Duration: 1.250 s"))
    XCTAssertTrue(description.contains("Status: AppleScript Compile Error"))
    XCTAssertTrue(description.contains("Error number: -2741"))
    XCTAssertTrue(description.contains("Source range: 12, 1"))
    XCTAssertTrue(description.contains("Expected expression but found end of script."))
  }
}
