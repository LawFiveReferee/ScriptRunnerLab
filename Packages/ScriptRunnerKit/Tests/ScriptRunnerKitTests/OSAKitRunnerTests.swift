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

  private func temporaryScript(containing source: String) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "ScriptRunnerKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let scriptURL = directoryURL.appending(path: "Test.applescript", directoryHint: .notDirectory)
    try source.write(to: scriptURL, atomically: true, encoding: .utf8)
    return scriptURL
  }
}
