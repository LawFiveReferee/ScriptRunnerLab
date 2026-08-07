import Foundation
import ScriptRunnerKit

struct CompatibilityTestResult: Sendable {
  var state: CompatibilityTestRunState
  var observedStatus: ScriptExecutionStatus?
  var errorNumber: Int?
  var message: String?
  var duration: TimeInterval?

  static let pending = CompatibilityTestResult(state: .pending)
  static let running = CompatibilityTestResult(state: .running)

  init(
    state: CompatibilityTestRunState,
    observedStatus: ScriptExecutionStatus? = nil,
    errorNumber: Int? = nil,
    message: String? = nil,
    duration: TimeInterval? = nil
  ) {
    self.state = state
    self.observedStatus = observedStatus
    self.errorNumber = errorNumber
    self.message = message
    self.duration = duration
  }
}

enum CompatibilityTestRunState: String, Sendable {
  case pending
  case running
  case passed
  case failed
  case stopped

  var displayName: String {
    rawValue.capitalized
  }
}
