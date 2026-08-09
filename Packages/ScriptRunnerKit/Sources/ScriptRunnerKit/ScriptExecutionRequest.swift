import Foundation

public struct ScriptExecutionRequest: Codable, Sendable {
  public var requestID: UUID
  public var scriptURL: URL
  public var securityScopedBookmark: Data?
  public var identity: ScriptExecutionIdentity?

  public init(scriptURL: URL, identity: ScriptExecutionIdentity? = nil) throws {
    self.requestID = UUID()
    self.scriptURL = scriptURL
    self.identity = identity
    self.securityScopedBookmark = try scriptURL.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  public init(
    requestID: UUID = UUID(),
    scriptURL: URL,
    securityScopedBookmark: Data?,
    identity: ScriptExecutionIdentity? = nil
  ) {
    self.requestID = requestID
    self.scriptURL = scriptURL
    self.securityScopedBookmark = securityScopedBookmark
    self.identity = identity
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
