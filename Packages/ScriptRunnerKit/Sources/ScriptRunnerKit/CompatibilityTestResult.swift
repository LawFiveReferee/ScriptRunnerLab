import Foundation

public struct CompatibilityTestResult: Sendable {
  public var state: CompatibilityTestRunState
  public var observedStatus: ScriptExecutionStatus?
  public var errorNumber: Int?
  public var message: String?
  public var duration: TimeInterval?

  public static let pending = CompatibilityTestResult(state: .pending)
  public static let running = CompatibilityTestResult(state: .running)

  public init(
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

public enum CompatibilityTestRunState: String, Codable, Equatable, Sendable {
  case pending
  case running
  case passed
  case failed
  case stopped

  public var displayName: String {
    rawValue.capitalized
  }
}
