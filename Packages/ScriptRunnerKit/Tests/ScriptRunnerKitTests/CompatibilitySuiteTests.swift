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

  func testPortableSummaryRoundTripsAndFormatsHostDetails() throws {
    let automaticTest = makeTest(path: "Pass.applescript", expectedSource: "1")
    let deferredTest = CompatibilityTestDefinition(
      relativePath: "Dialog.applescript",
      displayName: "Dialog.applescript",
      disposition: .manual(reason: "Requires a response."),
      expectedOutcome: nil,
      timeout: 0
    )
    let configuration = ScriptRunnerHostConfiguration(
      helperExecutableURL: URL(fileURLWithPath: "/tmp/Helper"),
      workingDirectoryName: "Tests",
      logURL: URL(fileURLWithPath: "/tmp/Execution.jsonl"),
      host: .init(name: "Host App", bundleIdentifier: "org.example.host", version: "2.0", build: "9"),
      environment: .init(
        operatingSystem: "Test macOS",
        architecture: "Test Architecture",
        isSandboxed: false,
        isolation: "Test Helper"
      )
    )
    let summary = CompatibilitySuiteSummary(
      suiteName: "Host Compatibility Suite",
      generatedAt: Date(timeIntervalSince1970: 30),
      startedAt: Date(timeIntervalSince1970: 10),
      completedAt: Date(timeIntervalSince1970: 20),
      configuration: configuration,
      automaticTests: [automaticTest],
      results: [automaticTest.id: CompatibilityTestResult(state: .passed, observedStatus: .completed)],
      deferredTests: [deferredTest]
    )

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(CompatibilitySuiteSummary.self, from: summary.jsonData())

    XCTAssertEqual(decoded.host.name, "Host App")
    XCTAssertEqual(decoded.entries.first?.state, .passed)
    XCTAssertEqual(decoded.deferredTests.first?.reason, "Requires a response.")
    XCTAssertTrue(decoded.text.contains("Version: 2.0 (9)"))
    XCTAssertTrue(decoded.text.contains("[PASSED] Pass.applescript"))
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
