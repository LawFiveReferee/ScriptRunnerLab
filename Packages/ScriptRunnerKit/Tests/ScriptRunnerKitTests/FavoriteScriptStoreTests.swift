import XCTest
@testable import ScriptRunnerKit

final class FavoriteScriptStoreTests: XCTestCase {
  @MainActor
  func testLoadsExistingJSONAndPreservesStorageFormat() throws {
    let context = makeDefaultsContext()
    defer { cleanUp(context) }
    let favorite = try makeFavorite(named: "Existing.applescript", in: context.directory)
    let data = try JSONEncoder().encode([favorite])
    context.defaults.set(String(decoding: data, as: UTF8.self), forKey: context.storageKey)

    let store = FavoriteScriptStore(
      defaults: context.defaults,
      storageKey: context.storageKey
    )

    XCTAssertEqual(store.favorites.map(\.id), [favorite.id])
    XCTAssertEqual(store.favoriteID(for: URL(fileURLWithPath: favorite.lastKnownPath)), favorite.id)
  }

  @MainActor
  func testAddSortRemoveAndPersist() throws {
    let context = makeDefaultsContext()
    defer { cleanUp(context) }
    let store = FavoriteScriptStore(
      defaults: context.defaults,
      storageKey: context.storageKey
    )

    let zulu = try store.add(makeDescriptor(named: "Zulu.applescript", in: context.directory))
    let alpha = try store.add(makeDescriptor(named: "Alpha.applescript", in: context.directory))
    _ = try store.add(makeDescriptor(named: "Alpha.applescript", in: context.directory))

    XCTAssertEqual(store.favorites.map(\.displayName), ["Alpha.applescript", "Zulu.applescript"])
    store.remove(id: zulu.id)
    XCTAssertEqual(store.favorites.map(\.id), [alpha.id])

    let reloaded = FavoriteScriptStore(
      defaults: context.defaults,
      storageKey: context.storageKey
    )
    XCTAssertEqual(reloaded.favorites.map(\.id), [alpha.id])
  }

  @MainActor
  func testResolveRefreshesMetadataWhilePreservingIdentity() throws {
    let context = makeDefaultsContext()
    defer { cleanUp(context) }
    let store = FavoriteScriptStore(
      defaults: context.defaults,
      storageKey: context.storageKey
    )
    let favorite = try store.add(makeDescriptor(named: "Favorite.applescript", in: context.directory))

    let resolution = try store.resolveAndRefresh(id: favorite.id)

    XCTAssertEqual(resolution.favorite.id, favorite.id)
    XCTAssertEqual(resolution.url.standardizedFileURL.path, favorite.lastKnownPath)
    XCTAssertFalse(resolution.bookmarkWasStale)
    XCTAssertEqual(store.favorites.first?.id, favorite.id)
  }

  @MainActor
  func testReplacementRestoresARecordWithBrokenBookmark() throws {
    let context = makeDefaultsContext()
    defer { cleanUp(context) }
    let id = UUID()
    let storedValue =
      """
      [{"id":"\(id.uuidString)","bookmark":"AA==","displayName":"Missing.applescript","lastKnownPath":"/Missing.applescript","fileExtension":"applescript","scriptType":"sourceAppleScript","capabilities":[]}]
      """
    context.defaults.set(storedValue, forKey: context.storageKey)
    let store = FavoriteScriptStore(
      defaults: context.defaults,
      storageKey: context.storageKey
    )

    XCTAssertThrowsError(try store.resolveAndRefresh(id: id))
    let replacement = try store.replace(
      id: id,
      with: makeDescriptor(named: "Restored.applescript", in: context.directory)
    )

    XCTAssertEqual(replacement.id, id)
    XCTAssertEqual(store.favorites.first?.displayName, "Restored.applescript")
    XCTAssertNoThrow(try store.resolveAndRefresh(id: id))
  }

  private func makeDefaultsContext() -> DefaultsContext {
    let suiteName = "FavoriteScriptStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let directory = FileManager.default.temporaryDirectory.appending(
      path: suiteName,
      directoryHint: .isDirectory
    )
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return DefaultsContext(
      suiteName: suiteName,
      storageKey: "favorites",
      defaults: defaults,
      directory: directory
    )
  }

  private func cleanUp(_ context: DefaultsContext) {
    context.defaults.removePersistentDomain(forName: context.suiteName)
    try? FileManager.default.removeItem(at: context.directory)
  }

  private func makeFavorite(named name: String, in directory: URL) throws -> FavoriteScript {
    try FavoriteScript(descriptor: makeDescriptor(named: name, in: directory))
  }

  private func makeDescriptor(named name: String, in directory: URL) throws -> ScriptDescriptor {
    let url = directory.appending(path: name)
    if !FileManager.default.fileExists(atPath: url.path) {
      try Data("return 1".utf8).write(to: url)
    }
    return ScriptDescriptor(url: url)
  }
}

private struct DefaultsContext {
  var suiteName: String
  var storageKey: String
  var defaults: UserDefaults
  var directory: URL
}
