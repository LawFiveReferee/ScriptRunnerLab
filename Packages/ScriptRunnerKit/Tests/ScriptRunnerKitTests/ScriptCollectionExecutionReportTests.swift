import XCTest
@testable import ScriptRunnerKit

final class ScriptCollectionExecutionReportTests: XCTestCase {
  func testTextPreservesOrderNamesResultsAndErrors() {
    let report = makeReport()

    XCTAssertEqual(
      report.text,
      "First.applescript\n\"First result\"\n\nSecond.applescript\nFailed\nIntentional error\nError number: -2700"
    )
    XCTAssertFalse(report.succeeded)
  }

  func testReportRoundTripsThroughJSON() throws {
    let report = makeReport()
    let decoded = try JSONDecoder().decode(
      ScriptCollectionExecutionReport.self,
      from: JSONEncoder().encode(report)
    )

    XCTAssertEqual(decoded.schemaVersion, 1)
    XCTAssertEqual(decoded.mode, .automatically)
    XCTAssertEqual(decoded.directoryPath, "/Scripts")
    XCTAssertEqual(decoded.entries.map(\.relativePath), ["First.applescript", "Second.applescript"])
    XCTAssertEqual(decoded.text, report.text)
  }

  private func makeReport() -> ScriptCollectionExecutionReport {
    let startedAt = Date(timeIntervalSince1970: 100)
    return ScriptCollectionExecutionReport(
      mode: .automatically,
      directoryPath: "/Scripts",
      startedAt: startedAt,
      completedAt: startedAt.addingTimeInterval(2),
      entries: [
        ScriptCollectionEntryResult(
          relativePath: "First.applescript",
          result: ScriptExecutionResult(
            requestID: UUID(),
            status: .completed,
            sourceResultDescription: "\"First result\"",
            rawResultDescription: nil,
            errorNumber: nil,
            errorMessage: nil,
            errorBriefMessage: nil,
            errorRange: nil,
            executionDuration: 1,
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(1)
          )
        ),
        ScriptCollectionEntryResult(
          relativePath: "Second.applescript",
          result: ScriptExecutionResult(
            requestID: UUID(),
            status: .failed,
            sourceResultDescription: nil,
            rawResultDescription: nil,
            errorNumber: -2700,
            errorMessage: "Intentional error",
            errorBriefMessage: nil,
            errorRange: nil,
            executionDuration: 1,
            startedAt: startedAt.addingTimeInterval(1),
            completedAt: startedAt.addingTimeInterval(2)
          )
        )
      ]
    )
  }
}
