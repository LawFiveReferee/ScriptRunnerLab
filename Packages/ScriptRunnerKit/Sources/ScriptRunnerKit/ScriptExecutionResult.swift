import Foundation

public struct ScriptExecutionResult: Codable, Sendable {
  public var requestID: UUID
  public var status: ScriptExecutionStatus
  public var sourceResultDescription: String?
  public var rawResultDescription: String?
  public var errorNumber: Int?
  public var errorMessage: String?
  public var errorBriefMessage: String?
  public var errorRange: ScriptSourceRange?
  public var executionDuration: TimeInterval
  public var startedAt: Date
  public var completedAt: Date

  public init(
    requestID: UUID,
    status: ScriptExecutionStatus,
    sourceResultDescription: String?,
    rawResultDescription: String?,
    errorNumber: Int?,
    errorMessage: String?,
    errorBriefMessage: String?,
    errorRange: ScriptSourceRange?,
    executionDuration: TimeInterval,
    startedAt: Date,
    completedAt: Date
  ) {
    self.requestID = requestID
    self.status = status
    self.sourceResultDescription = sourceResultDescription
    self.rawResultDescription = rawResultDescription
    self.errorNumber = errorNumber
    self.errorMessage = errorMessage
    self.errorBriefMessage = errorBriefMessage
    self.errorRange = errorRange
    self.executionDuration = executionDuration
    self.startedAt = startedAt
    self.completedAt = completedAt
  }

  public static func failure(
    requestID: UUID,
    status: ScriptExecutionStatus = .failed,
    message: String,
    startedAt: Date = Date(),
    completedAt: Date = Date()
  ) -> ScriptExecutionResult {
    ScriptExecutionResult(
      requestID: requestID,
      status: status,
      sourceResultDescription: nil,
      rawResultDescription: nil,
      errorNumber: nil,
      errorMessage: message,
      errorBriefMessage: nil,
      errorRange: nil,
      executionDuration: completedAt.timeIntervalSince(startedAt),
      startedAt: startedAt,
      completedAt: completedAt
    )
  }
}

public struct ScriptSourceRange: Codable, Sendable {
  public var location: Int
  public var length: Int

  public init(location: Int, length: Int) {
    self.location = location
    self.length = length
  }
}

public enum ScriptExecutionStatus: String, Codable, Equatable, Sendable {
  case ready
  case running
  case completed
  case compileError
  case failed
  case cancelled
  case timedOut
  case busy

  public var displayName: String {
    switch self {
    case .compileError: "AppleScript Compile Error"
    case .timedOut: "Timed Out"
    case .busy: "Busy"
    default: rawValue.capitalized
    }
  }
}
