import Foundation

public struct ScriptProgressSnapshot: Codable, Equatable, Sendable {
  public var requestID: UUID
  public var totalSteps: Int64
  public var completedSteps: Int64
  public var progressDescription: String?
  public var additionalDescription: String?
  public var updatedAt: Date

  public init(
    requestID: UUID,
    totalSteps: Int64,
    completedSteps: Int64,
    progressDescription: String?,
    additionalDescription: String?,
    updatedAt: Date = Date()
  ) {
    self.requestID = requestID
    self.totalSteps = totalSteps
    self.completedSteps = completedSteps
    self.progressDescription = progressDescription
    self.additionalDescription = additionalDescription
    self.updatedAt = updatedAt
  }

  public var isIndeterminate: Bool {
    totalSteps < 0 || completedSteps < 0
  }

  public var fractionCompleted: Double {
    guard totalSteps > 0 else { return 0 }
    return min(max(Double(completedSteps) / Double(totalSteps), 0), 1)
  }
}
