import XCTest
@testable import ScriptRunnerKit

final class ScriptRunnerHelperInvocationTests: XCTestCase {
  func testInvocationMapsThreeFileArguments() throws {
    let invocation = try ScriptRunnerHelperInvocation(
      arguments: ["helper", "/tmp/request.json", "/tmp/result.json", "/tmp/progress.json"]
    )

    XCTAssertEqual(invocation.requestURL.path, "/tmp/request.json")
    XCTAssertEqual(invocation.resultURL.path, "/tmp/result.json")
    XCTAssertEqual(invocation.progressURL.path, "/tmp/progress.json")
  }

  func testInvocationRejectsMissingArguments() {
    XCTAssertThrowsError(try ScriptRunnerHelperInvocation(arguments: ["helper"])) { error in
      XCTAssertEqual(error as? ScriptRunnerHelperInvocationError, .invalidArgumentCount(1))
    }
  }
}
