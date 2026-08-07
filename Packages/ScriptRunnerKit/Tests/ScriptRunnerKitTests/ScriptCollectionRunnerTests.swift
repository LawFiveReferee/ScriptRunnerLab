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
}
