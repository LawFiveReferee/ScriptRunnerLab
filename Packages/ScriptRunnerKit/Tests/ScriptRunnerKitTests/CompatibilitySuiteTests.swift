import XCTest
@testable import ScriptRunnerKit

final class CompatibilitySuiteTests: XCTestCase {
  func testBaselineManifestPreservesAutomaticTestsAndAssertions() {
    XCTAssertEqual(CompatibilityTestDefinition.automaticTests.count, 20)
    XCTAssertEqual(
      CompatibilityTestDefinition.automaticTests.reduce(0) {
        $0 + ($1.expectedOutcome?.assertions.count ?? 0)
      },
      26
    )
  }

  @MainActor
  func testSuiteRunnerReturnsOrderedPassAndFailureResults() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "CompatibilitySuiteTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("return 1".utf8).write(to: directory.appending(path: "Pass.applescript"))
    try Data("return 2".utf8).write(to: directory.appending(path: "Fail.applescript"))
    let tests = [
      makeTest(path: "Pass.applescript", expectedSource: "1"),
      makeTest(path: "Fail.applescript", expectedSource: "1")
    ]
    let configuration = ScriptRunnerHostConfiguration(
      helperExecutableURL: directory.appending(path: "UnusedHelper"),
      workingDirectoryName: "Tests",
      logURL: nil,
      host: .init(name: "Tests", bundleIdentifier: nil, version: nil, build: nil),
      environment: .init(
        operatingSystem: "Tests",
        architecture: "Tests",
        isSandboxed: false,
        isolation: "Tests"
      )
    )
    let service = ScriptRunnerService(configuration: configuration, requestExecutor: { request, _, _ in
      let now = Date()
      let source = request.scriptURL.lastPathComponent == "Pass.applescript" ? "1" : "2"
      return ScriptExecutionResult(
        requestID: request.requestID,
        status: .completed,
        sourceResultDescription: source,
        rawResultDescription: source,
        errorNumber: nil,
        errorMessage: nil,
        errorBriefMessage: nil,
        errorRange: nil,
        executionDuration: 0,
        startedAt: now,
        completedAt: now
      )
    })

    let report = await service.executeCompatibilitySuite(testsRootURL: directory, tests: tests)

    XCTAssertEqual(report.entries.map(\.test.relativePath), ["Pass.applescript", "Fail.applescript"])
    XCTAssertEqual(report.entries.map(\.result.state), [.passed, .failed])
    XCTAssertEqual(report.passedCount, 1)
    XCTAssertEqual(report.failedCount, 1)
    XCTAssertEqual(report.completion, .finished)
  }

  private func makeTest(path: String, expectedSource: String) -> CompatibilityTestDefinition {
    CompatibilityTestDefinition(
      relativePath: path,
      displayName: path,
      disposition: .automatic,
      expectedOutcome: .completed(sourceEquals: expectedSource),
      timeout: 10
    )
  }
}
