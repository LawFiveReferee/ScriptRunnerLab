import Foundation

public struct CompatibilitySuiteReport: Sendable {
  public var startedAt: Date
  public var completedAt: Date
  public var completion: CompatibilitySuiteCompletion
  public var entries: [CompatibilitySuiteEntry]

  public init(
    startedAt: Date,
    completedAt: Date,
    completion: CompatibilitySuiteCompletion,
    entries: [CompatibilitySuiteEntry]
  ) {
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.completion = completion
    self.entries = entries
  }

  public var passedCount: Int {
    entries.filter { $0.result.state == .passed }.count
  }

  public var failedCount: Int {
    entries.filter { $0.result.state == .failed }.count
  }
}

public struct CompatibilitySuiteEntry: Sendable {
  public var test: CompatibilityTestDefinition
  public var result: CompatibilityTestResult

  public init(test: CompatibilityTestDefinition, result: CompatibilityTestResult) {
    self.test = test
    self.result = result
  }
}

public enum CompatibilitySuiteCompletion: Equatable, Sendable {
  case finished
  case stopped
}
