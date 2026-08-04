import Foundation

struct ScriptExecutionResult: Sendable {
  var requestID: UUID
  var status: ScriptExecutionStatus
  var sourceResultDescription: String?
  var rawResultDescription: String?
  var errorNumber: Int?
  var errorMessage: String?
  var errorBriefMessage: String?
  var errorRange: NSRange?
  var executionDuration: TimeInterval
  var startedAt: Date
  var completedAt: Date
}

enum ScriptExecutionStatus: String, Sendable {
  case ready
  case running
  case completed
  case failed

  var displayName: String {
    rawValue.capitalized
  }
}
