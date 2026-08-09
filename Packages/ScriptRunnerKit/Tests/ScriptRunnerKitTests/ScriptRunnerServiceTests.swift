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
    var requestIdentity: ScriptExecutionIdentity?
    let service = ScriptRunnerService(configuration: configuration, requestExecutor: { request, _, _ in
      requestIdentity = request.identity
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
    XCTAssertEqual(requestIdentity, .inferred(from: scriptURL))
    let line = try XCTUnwrap(String(data: Data(contentsOf: logURL), encoding: .utf8)?.split(separator: "\n").first)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let entry = try decoder.decode(ScriptExecutionLogEntry.self, from: Data(line.utf8))
    XCTAssertEqual(entry.host.name, "Test Host")
    XCTAssertEqual(entry.script.name, "Example.applescript")
    XCTAssertEqual(entry.result.sourceResultDescription, "1")
  }

  @MainActor
  func testLogicalIdentityReachesRequestProgressAndLog() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptRunnerIdentityTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let temporaryScriptURL = directory.appending(path: "\(UUID().uuidString).applescript")
    let originalURL = directory.appending(path: "Original Scripts/My Command.applescript")
    let logURL = directory.appending(path: "Execution.jsonl")
    try Data("return 1".utf8).write(to: temporaryScriptURL)
    let identity = ScriptExecutionIdentity(displayName: "My Stored Command", originalURL: originalURL)
    var receivedRequestIdentity: ScriptExecutionIdentity?
    var receivedProgressIdentity: ScriptExecutionIdentity?
    let service = ScriptRunnerService(
      configuration: testConfiguration(in: directory, logURL: logURL),
      requestExecutor: { request, _, progressHandler in
        receivedRequestIdentity = request.identity
        progressHandler(
          ScriptProgressSnapshot(
            requestID: request.requestID,
            totalSteps: 1,
            completedSteps: 1,
            progressDescription: "Done",
            additionalDescription: nil
          )
        )
        return Self.completedResult(requestID: request.requestID)
      }
    )

    _ = await service.execute(
      scriptURL: temporaryScriptURL,
      identity: identity,
      timeout: 30
    ) { snapshot in
      receivedProgressIdentity = snapshot.scriptIdentity
    }

    XCTAssertEqual(receivedRequestIdentity, identity)
    XCTAssertEqual(receivedProgressIdentity, identity)
    let line = try XCTUnwrap(
      String(data: Data(contentsOf: logURL), encoding: .utf8)?.split(separator: "\n").first
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let entry = try decoder.decode(ScriptExecutionLogEntry.self, from: Data(line.utf8))
    XCTAssertEqual(entry.script.name, "My Stored Command")
    XCTAssertEqual(entry.script.path, originalURL.path)
    XCTAssertEqual(entry.script.fileExtension, "applescript")
  }

  @MainActor
  func testHelperExitWithoutResultProducesNamedTimedFailure() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptRunnerExitTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let scriptURL = directory.appending(path: "Temporary.applescript")
    try Data("return 1".utf8).write(to: scriptURL)
    let identity = ScriptExecutionIdentity(displayName: "Named Script")
    let service = ScriptRunnerService(
      configuration: testConfiguration(in: directory),
      requestExecutor: { _, _, _ in
        throw ScriptHelperProcessError.exitedWithoutResult(9)
      }
    )

    let result = await service.execute(
      scriptURL: scriptURL,
      identity: identity,
      timeout: 30
    )
    let description = ScriptExecutionFailureFormatter().string(from: result, identity: identity)

    XCTAssertEqual(result.status, .failed)
    XCTAssertGreaterThanOrEqual(result.executionDuration, 0)
    XCTAssertTrue(description.contains("Script: Named Script"))
    XCTAssertTrue(description.contains("Duration:"))
    XCTAssertTrue(description.contains("exited without a result (status 9)"))
  }

  @MainActor
  func testOverlappingExecutionIsRejectedWithoutReplacingCancellationOwner() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptRunnerOverlapTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let firstURL = directory.appending(path: "First.applescript")
    let secondURL = directory.appending(path: "Second.applescript")
    try Data("delay 5".utf8).write(to: firstURL)
    try Data("return 2".utf8).write(to: secondURL)
    var executionCount = 0
    var cancellationCount = 0
    let service = ScriptRunnerService(
      configuration: testConfiguration(in: directory),
      requestExecutor: { request, _, _ in
        executionCount += 1
        do {
          try await Task.sleep(for: .seconds(5))
          return Self.completedResult(requestID: request.requestID)
        } catch {
          throw ScriptHelperProcessError.cancelled
        }
      },
      cancellationHandler: {
        cancellationCount += 1
      }
    )

    let firstTask = Task { await service.execute(scriptURL: firstURL, timeout: 30) }
    while !service.isBusy {
      await Task.yield()
    }
    let rejected = await service.execute(scriptURL: secondURL, timeout: 30)
    service.cancel()
    let first = await firstTask.value

    XCTAssertEqual(rejected.status, .busy)
    XCTAssertTrue(rejected.errorMessage?.contains("Second.applescript") == true)
    XCTAssertEqual(executionCount, 1)
    XCTAssertEqual(cancellationCount, 1)
    XCTAssertEqual(first.status, .cancelled)
    XCTAssertFalse(service.isBusy)
  }

  private static func completedResult(requestID: UUID) -> ScriptExecutionResult {
    let now = Date()
    return ScriptExecutionResult(
      requestID: requestID,
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
  }

  private func testConfiguration(
    in directory: URL,
    logURL: URL? = nil
  ) -> ScriptRunnerHostConfiguration {
    ScriptRunnerHostConfiguration(
      helperExecutableURL: directory.appending(path: "UnusedHelper"),
      workingDirectoryName: "Tests",
      logURL: logURL,
      host: .init(name: "Test Host", bundleIdentifier: nil, version: nil, build: nil),
      environment: .init(
        operatingSystem: "Test macOS",
        architecture: "Test Architecture",
        isSandboxed: false,
        isolation: "Test Helper"
      )
    )
  }
}
