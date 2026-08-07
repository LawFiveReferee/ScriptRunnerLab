import Foundation
import ScriptRunnerKit
import XCTest

final class OSAKitRunnerTests: XCTestCase {
  func testSyntaxErrorIsReportedAsCompileError() throws {
    let scriptURL = try temporaryScript(containing: "return \"This string is never closed")
    defer { try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent()) }

    let result = OSAKitRunner().execute(url: scriptURL)

    XCTAssertEqual(result.status, .compileError)
    XCTAssertEqual(result.errorNumber, -2741)
    XCTAssertTrue(result.errorMessage?.contains("end of script") == true)
    XCTAssertNotNil(result.errorRange)
  }

  func testRuntimeErrorRemainsAnExecutionFailure() throws {
    let scriptURL = try temporaryScript(containing: "error \"Expected runtime failure\" number -2700")
    defer { try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent()) }

    let result = OSAKitRunner().execute(url: scriptURL)

    XCTAssertEqual(result.status, .failed)
    XCTAssertEqual(result.errorNumber, -2700)
    XCTAssertEqual(result.errorMessage, "Expected runtime failure")
  }

  func testBuiltInAppleScriptProgressIsPublished() throws {
    let scriptURL = try temporaryScript(
      containing: """
      set progress total steps to 10
      set progress completed steps to 4
      set progress description to "Testing"
      set progress additional description to "Step four"
      return "Progress reported"
      """
    )
    defer { try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent()) }
    var updates: [ScriptProgressSnapshot] = []

    let result = OSAKitRunner().execute(url: scriptURL) { snapshot in
      updates.append(snapshot)
    }

    XCTAssertEqual(result.status, .completed)
    XCTAssertTrue(
      updates.contains { $0.totalSteps == 10 && $0.completedSteps == 4 },
      "Updates: \(updates)"
    )
    XCTAssertTrue(updates.contains { $0.progressDescription == "Testing" }, "Updates: \(updates)")
    XCTAssertTrue(updates.contains { $0.additionalDescription == "Step four" }, "Updates: \(updates)")
  }

  private func temporaryScript(containing source: String) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "ScriptRunnerKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let scriptURL = directoryURL.appending(path: "Test.applescript", directoryHint: .notDirectory)
    try source.write(to: scriptURL, atomically: true, encoding: .utf8)
    return scriptURL
  }
}
