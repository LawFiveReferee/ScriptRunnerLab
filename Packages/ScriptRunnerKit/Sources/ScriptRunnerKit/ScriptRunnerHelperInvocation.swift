import Foundation

public struct ScriptRunnerHelperInvocation: Equatable, Sendable {
  public var requestURL: URL
  public var resultURL: URL
  public var progressURL: URL

  public init(arguments: [String]) throws {
    guard arguments.count == 4 else {
      throw ScriptRunnerHelperInvocationError.invalidArgumentCount(arguments.count)
    }
    self.requestURL = URL(fileURLWithPath: arguments[1])
    self.resultURL = URL(fileURLWithPath: arguments[2])
    self.progressURL = URL(fileURLWithPath: arguments[3])
  }
}

public enum ScriptRunnerHelperInvocationError: LocalizedError, Equatable, Sendable {
  case invalidArgumentCount(Int)

  public var errorDescription: String? {
    switch self {
    case .invalidArgumentCount(let count):
      "ScriptRunnerHelper expected three file arguments but received \(max(0, count - 1))."
    }
  }
}
