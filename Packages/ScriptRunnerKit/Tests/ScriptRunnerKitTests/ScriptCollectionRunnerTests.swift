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

  func testDiscoveryTreatsScriptBundlesAndAppletsAsLeafItems() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptCollectionLeafTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let bundleScripts = directory.appending(
      path: "Bundle.scptd/Contents/Resources/Scripts",
      directoryHint: .isDirectory
    )
    let appletScripts = directory.appending(
      path: "Applet.app/Contents/Resources/Scripts",
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: bundleScripts, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: appletScripts, withIntermediateDirectories: true)
    try Data().write(to: bundleScripts.appending(path: "main.scpt"))
    try Data().write(to: bundleScripts.appending(path: "Nested.applescript"))
    try Data().write(to: appletScripts.appending(path: "main.scpt"))
    try Data().write(to: appletScripts.appending(path: "Nested.applescript"))

    let items = ScriptCollectionDiscovery().scripts(in: directory)

    XCTAssertEqual(items.map(\.relativePath), ["Applet.app", "Bundle.scptd"])
    XCTAssertEqual(items.map(\.descriptor.scriptType), [.appleScriptApplet, .scriptBundle])
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

  @MainActor
  func testAutomaticExecutionRemainsSequentialAndDeterministic() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptCollectionSequentialTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data().write(to: directory.appending(path: "C.applescript"))
    try Data().write(to: directory.appending(path: "A.applescript"))
    try Data().write(to: directory.appending(path: "B.applescript"))
    var activeCount = 0
    var maximumActiveCount = 0
    var executionOrder: [String] = []
    let runner = ScriptCollectionRunner(requestExecutor: { request, _, _ in
      activeCount += 1
      maximumActiveCount = max(maximumActiveCount, activeCount)
      executionOrder.append(request.scriptURL.lastPathComponent)
      try await Task.sleep(for: .milliseconds(5))
      activeCount -= 1
      let now = Date()
      return ScriptExecutionResult(
        requestID: request.requestID,
        status: .completed,
        sourceResultDescription: nil,
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

    let report = try await runner.execute(directoryURL: directory, timeout: 30)

    XCTAssertEqual(executionOrder, ["A.applescript", "B.applescript", "C.applescript"])
    XCTAssertEqual(report.entries.map(\.relativePath), executionOrder)
    XCTAssertEqual(maximumActiveCount, 1)
  }
}
