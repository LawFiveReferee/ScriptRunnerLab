import Foundation

public struct FavoriteScript: Codable, Identifiable, Sendable {
  public var id: UUID
  public var bookmark: String
  public var displayName: String
  public var lastKnownPath: String
  public var fileExtension: String
  public var scriptType: ScriptType
  public var capabilities: [ScriptCapability]

  public init(descriptor: ScriptDescriptor) throws {
    try self.init(
      descriptor: descriptor,
      capabilities: ScriptCapability.detect(in: descriptor)
    )
  }

  public init(descriptor: ScriptDescriptor, capabilities: [ScriptCapability]) throws {
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

  public init(id: UUID, replacing favorite: FavoriteScript) {
    self = favorite
    self.id = id
  }

  public func resolvedURL() throws -> (url: URL, isStale: Bool) {
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
