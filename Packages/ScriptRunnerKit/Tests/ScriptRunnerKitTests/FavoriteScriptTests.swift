import XCTest
@testable import ScriptRunnerKit

final class FavoriteScriptTests: XCTestCase {
  func testDecodesExistingStoredFavorite() throws {
    let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let data = Data(
      """
      {
        "id":"\(id.uuidString)",
        "bookmark":"AA==",
        "displayName":"Example.applescript",
        "lastKnownPath":"/Scripts/Example.applescript",
        "fileExtension":"applescript",
        "scriptType":"sourceAppleScript",
        "capabilities":[{"kind":"framework","detail":"Foundation"}]
      }
      """.utf8
    )

    let favorite = try JSONDecoder().decode(FavoriteScript.self, from: data)

    XCTAssertEqual(favorite.id, id)
    XCTAssertEqual(favorite.lastKnownPath, "/Scripts/Example.applescript")
    XCTAssertEqual(favorite.scriptType, .sourceAppleScript)
    XCTAssertEqual(favorite.capabilities, [ScriptCapability(kind: .framework, detail: "Foundation")])
  }

  func testFavoriteCreatesAndResolvesSecurityScopedBookmark() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "FavoriteScriptTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let scriptURL = directory.appending(path: "Favorite.applescript")
    try Data("return 1".utf8).write(to: scriptURL)

    let favorite = try FavoriteScript(descriptor: ScriptDescriptor(url: scriptURL))
    let resolved = try favorite.resolvedURL()

    XCTAssertEqual(resolved.url.standardizedFileURL, scriptURL.standardizedFileURL)
    XCTAssertFalse(resolved.isStale)
  }
}
