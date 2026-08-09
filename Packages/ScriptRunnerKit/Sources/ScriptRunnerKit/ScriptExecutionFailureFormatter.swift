import Foundation

public struct ScriptExecutionFailureFormatter: Sendable {
  public var includesScriptName: Bool
  public var includesDuration: Bool
  public var includesStatus: Bool
  public var includesErrorNumber: Bool
  public var includesSourceRange: Bool
  public var includesMessage: Bool

  public init(
    includesScriptName: Bool = true,
    includesDuration: Bool = true,
    includesStatus: Bool = true,
    includesErrorNumber: Bool = true,
    includesSourceRange: Bool = true,
    includesMessage: Bool = true
  ) {
    self.includesScriptName = includesScriptName
    self.includesDuration = includesDuration
    self.includesStatus = includesStatus
    self.includesErrorNumber = includesErrorNumber
    self.includesSourceRange = includesSourceRange
    self.includesMessage = includesMessage
  }

  public func string(
    from result: ScriptExecutionResult,
    identity: ScriptExecutionIdentity? = nil
  ) -> String {
    var lines: [String] = []
    if includesScriptName, let identity {
      lines.append("Script: \(identity.displayName)")
    }
    if includesDuration {
      lines.append("Duration: \(Self.durationString(result.executionDuration))")
    }
    if includesStatus {
      lines.append("Status: \(result.status.displayName)")
    }
    if includesErrorNumber, let errorNumber = result.errorNumber {
      lines.append("Error number: \(errorNumber)")
    }
    if includesSourceRange, let range = result.errorRange {
      lines.append("Source range: \(range.location), \(range.length)")
    }
    if includesMessage {
      let message = result.errorMessage ?? result.errorBriefMessage
      if let message, !message.isEmpty {
        lines.append("Error: \(message)")
      }
    }
    return lines.joined(separator: "\n")
  }

  private static func durationString(_ duration: TimeInterval) -> String {
    String(format: "%.3f s", locale: Locale(identifier: "en_US_POSIX"), max(duration, 0))
  }
}
