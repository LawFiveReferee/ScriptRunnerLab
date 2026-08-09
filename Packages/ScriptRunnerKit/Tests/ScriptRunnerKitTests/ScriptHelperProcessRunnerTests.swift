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

  @MainActor
  func testHelperExitWithoutResultReportsTerminationStatus() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptHelperExitTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let helperURL = directory.appending(path: "ExitHelper")
    try Data("#!/bin/sh\nexit 9\n".utf8).write(to: helperURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    let runner = ScriptHelperProcessRunner(
      helperExecutableURL: helperURL,
      temporaryDirectory: directory,
      workingDirectoryName: "Working"
    )
    let request = ScriptExecutionRequest(
      scriptURL: directory.appending(path: "Test.applescript"),
      securityScopedBookmark: nil,
      identity: ScriptExecutionIdentity(displayName: "Named Test")
    )

    do {
      _ = try await runner.execute(request: request, timeout: 1)
      XCTFail("Expected an exited-without-result error.")
    } catch let error as ScriptHelperProcessError {
      XCTAssertEqual(error, .exitedWithoutResult(9))
    }
  }
}
