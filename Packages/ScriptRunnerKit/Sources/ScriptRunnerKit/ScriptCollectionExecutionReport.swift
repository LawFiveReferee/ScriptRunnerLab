import Foundation

public struct ScriptCollectionExecutionReport: Codable, Sendable {
  public var schemaVersion: Int
  public var mode: ScriptCollectionExecutionMode
  public var directoryPath: String
  public var startedAt: Date
  public var completedAt: Date
  public var entries: [ScriptCollectionEntryResult]

  public init(
    schemaVersion: Int = 1,
    mode: ScriptCollectionExecutionMode,
    directoryPath: String,
    startedAt: Date,
    completedAt: Date,
    entries: [ScriptCollectionEntryResult]
  ) {
    self.schemaVersion = schemaVersion
    self.mode = mode
    self.directoryPath = directoryPath
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.entries = entries
  }

  public var text: String {
    entries.map(\.text).joined(separator: "\n\n")
  }

  public var succeeded: Bool {
    entries.allSatisfy { $0.result.status == .completed }
  }
}

public struct ScriptCollectionEntryResult: Codable, Sendable {
  public var relativePath: String
  public var result: ScriptExecutionResult

  public init(relativePath: String, result: ScriptExecutionResult) {
    self.relativePath = relativePath
    self.result = result
  }

  public var text: String {
    "\(relativePath)\n\(result.collectionResultText)"
  }
}

public enum ScriptCollectionExecutionMode: String, Codable, Equatable, Sendable {
  case automatically
  case interactively
}

private extension ScriptExecutionResult {
  var collectionResultText: String {
    if status == .completed {
      return sourceResultDescription
        ?? rawResultDescription
        ?? "Script completed without a result."
    }
    var lines = [status.displayName]
    if let message = errorMessage ?? errorBriefMessage {
      lines.append(message)
    }
    if let errorNumber {
      lines.append("Error number: \(errorNumber)")
    }
    return lines.joined(separator: "\n")
  }
}
