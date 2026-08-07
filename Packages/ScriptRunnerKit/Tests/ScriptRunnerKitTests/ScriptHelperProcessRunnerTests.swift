import XCTest
@testable import ScriptRunnerKit

final class ScriptHelperProcessRunnerTests: XCTestCase {
  @MainActor
  func testMissingHelperIsReportedBeforeExecution() async {
    let runner = ScriptHelperProcessRunner(
      helperExecutableURL: URL(fileURLWithPath: "/ScriptRunnerKitTests/MissingHelper")
    )
    let request = ScriptExecutionRequest(
      scriptURL: URL(fileURLWithPath: "/ScriptRunnerKitTests/Test.applescript"),
      securityScopedBookmark: nil
    )

    do {
      _ = try await runner.execute(request: request, timeout: 1)
      XCTFail("Expected the missing helper error.")
    } catch let error as ScriptHelperProcessError {
      XCTAssertEqual(error, .helperMissing)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
