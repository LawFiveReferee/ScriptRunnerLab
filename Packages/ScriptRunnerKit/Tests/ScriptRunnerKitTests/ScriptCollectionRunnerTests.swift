import XCTest
@testable import ScriptRunnerKit

final class ScriptCollectionRunnerTests: XCTestCase {
  func testDiscoveryFindsSupportedScriptsRecursivelyInSortedOrder() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptCollectionRunnerTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let nested = directory.appending(path: "Nested", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("return 2".utf8).write(to: nested.appending(path: "Second.applescript"))
    try Data("return 1".utf8).write(to: directory.appending(path: "First.applescript"))
    try Data().write(to: directory.appending(path: "Ignored.txt"))

    let items = ScriptCollectionDiscovery().scripts(in: directory)

    XCTAssertEqual(items.map(\.relativePath), ["First.applescript", "Nested/Second.applescript"])
    XCTAssertEqual(items.map(\.descriptor.scriptType), [.sourceAppleScript, .sourceAppleScript])
  }

  @MainActor
  func testInteractiveExecutionRepeatsAdvancesAndReturnsEveryResult() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptCollectionInteractiveTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("return 1".utf8).write(to: directory.appending(path: "First.applescript"))
    try Data("return 2".utf8).write(to: directory.appending(path: "Second.applescript"))

    var executedNames: [String] = []
    var actions: [ScriptCollectionInteractiveAction] = [.runAgain, .runNext, .runNext]
    let runner = ScriptCollectionRunner(requestExecutor: { request, _, _ in
      let name = request.scriptURL.lastPathComponent
      executedNames.append(name)
      let now = Date()
      return ScriptExecutionResult(
        requestID: request.requestID,
        status: .completed,
        sourceResultDescription: name,
        rawResultDescription: nil,
        errorNumber: nil,
        errorMessage: nil,
        errorBriefMessage: nil,
        errorRange: nil,
        executionDuration: 0,
        startedAt: now,
        completedAt: now
      )
    })

    let outcome = try await runner.executeInteractively(
      directoryURL: directory,
      timeout: 30
    ) { _ in
      actions.removeFirst()
    }

    XCTAssertEqual(executedNames, ["First.applescript", "First.applescript", "Second.applescript"])
    XCTAssertEqual(outcome.report.entries.map(\.relativePath), executedNames)
    XCTAssertEqual(outcome.report.mode, .interactively)
    XCTAssertEqual(outcome.completion, .finished)
  }
}
