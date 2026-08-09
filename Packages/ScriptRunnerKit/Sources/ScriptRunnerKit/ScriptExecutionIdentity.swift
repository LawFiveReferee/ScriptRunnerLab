import Foundation

/// The host-facing identity of a script, independent of the file used to execute it.
public struct ScriptExecutionIdentity: Codable, Equatable, Sendable {
  public var displayName: String
  public var originalURL: URL?

  public init(displayName: String, originalURL: URL? = nil) {
    self.displayName = displayName
    self.originalURL = originalURL
  }

  public static func inferred(from scriptURL: URL) -> ScriptExecutionIdentity {
    ScriptExecutionIdentity(displayName: scriptURL.lastPathComponent, originalURL: scriptURL)
  }
}
