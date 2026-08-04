import Foundation

struct FavoriteScript: Codable, Identifiable, Sendable {
  var id: UUID
  var bookmark: String
  var displayName: String
  var lastKnownPath: String
  var fileExtension: String
  var scriptType: ScriptType
  var capabilities: [ScriptCapability]

  init(descriptor: ScriptDescriptor, capabilities: [ScriptCapability]) throws {
    let bookmarkData = try descriptor.url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    self.id = UUID()
    self.bookmark = bookmarkData.base64EncodedString()
    self.displayName = descriptor.displayName
    self.lastKnownPath = descriptor.url.path(percentEncoded: false)
    self.fileExtension = descriptor.fileExtension
    self.scriptType = descriptor.scriptType
    self.capabilities = capabilities
  }

  init(id: UUID, replacing favorite: FavoriteScript) {
    self = favorite
    self.id = id
  }

  func resolvedURL() throws -> (url: URL, isStale: Bool) {
    guard let bookmarkData = Data(base64Encoded: bookmark) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    var isStale = false
    let url = try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
    return (url, isStale)
  }
}
