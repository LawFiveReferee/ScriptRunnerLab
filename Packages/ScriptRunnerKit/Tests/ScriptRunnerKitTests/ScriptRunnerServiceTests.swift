import XCTest
@testable import ScriptRunnerKit

final class ScriptRunnerServiceTests: XCTestCase {
  @MainActor
  func testSingleExecutionReturnsResultAndWritesHostLog() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptRunnerServiceTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let scriptURL = temporaryDirectory.appending(path: "Example.applescript")
    let logURL = temporaryDirectory.appending(path: "Execution.jsonl")
    try Data("return 1".utf8).write(to: scriptURL)
    let configuration = ScriptRunnerHostConfiguration(
      helperExecutableURL: temporaryDirectory.appending(path: "UnusedHelper"),
      workingDirectoryName: "Tests",
      logURL: logURL,
      host: .init(name: "Test Host", bundleIdentifier: "org.example.host", version: "1.2", build: "3"),
      environment: .init(
        operatingSystem: "Test macOS",
        architecture: "Test Architecture",
        isSandboxed: false,
        isolation: "Test Helper"
      )
    )
    let service = ScriptRunnerService(configuration: configuration, requestExecutor: { request, _, _ in
      let now = Date()
      return ScriptExecutionResult(
        requestID: request.requestID,
        status: .completed,
        sourceResultDescription: "1",
        rawResultDescription: "1",
        errorNumber: nil,
        errorMessage: nil,
        errorBriefMessage: nil,
        errorRange: nil,
        executionDuration: 0,
        startedAt: now,
        completedAt: now
      )
    })

    let result = await service.execute(scriptURL: scriptURL, timeout: 30)

    XCTAssertEqual(result.status, .completed)
    let line = try XCTUnwrap(String(data: Data(contentsOf: logURL), encoding: .utf8)?.split(separator: "\n").first)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let entry = try decoder.decode(ScriptExecutionLogEntry.self, from: Data(line.utf8))
    XCTAssertEqual(entry.host.name, "Test Host")
    XCTAssertEqual(entry.script.name, "Example.applescript")
    XCTAssertEqual(entry.result.sourceResultDescription, "1")
  }
}
