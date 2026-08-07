import Foundation

public struct ScriptExecutionRequest: Codable, Sendable {
  public var requestID: UUID
  public var scriptURL: URL
  public var securityScopedBookmark: Data?

  public init(scriptURL: URL) throws {
    self.requestID = UUID()
    self.scriptURL = scriptURL
    self.securityScopedBookmark = try scriptURL.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  public init(requestID: UUID = UUID(), scriptURL: URL, securityScopedBookmark: Data?) {
    self.requestID = requestID
    self.scriptURL = scriptURL
    self.securityScopedBookmark = securityScopedBookmark
  }

  public func resolveScriptURL() throws -> URL {
    guard let securityScopedBookmark else { return scriptURL }
    var isStale = false
    do {
      return try URL(
        resolvingBookmarkData: securityScopedBookmark,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    } catch {
      return scriptURL
    }
  }
}
