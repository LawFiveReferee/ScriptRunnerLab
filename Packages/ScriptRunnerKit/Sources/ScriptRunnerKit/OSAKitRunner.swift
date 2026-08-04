import Foundation
import OSAKit

public struct OSAKitRunner {
  public init() {}

  public func execute(request: ScriptExecutionRequest) -> ScriptExecutionResult {
    let startedAt = Date()

    do {
      let url = try request.resolveScriptURL()
      let accessed = url.startAccessingSecurityScopedResource()
      defer {
        if accessed {
          url.stopAccessingSecurityScopedResource()
        }
      }
      return execute(url: url, requestID: request.requestID, startedAt: startedAt)
    } catch {
      return .failure(
        requestID: request.requestID,
        message: "The helper could not access the selected script. \(error.localizedDescription)",
        startedAt: startedAt
      )
    }
  }

  public func execute(url: URL, requestID: UUID = UUID(), startedAt: Date = Date()) -> ScriptExecutionResult {
    var loadError: NSDictionary?

    guard let script = OSAScript(contentsOf: url, error: &loadError) else {
      return failureResult(
        requestID: requestID,
        startedAt: startedAt,
        error: loadError,
        fallbackMessage: "OSAKit could not load this script."
      )
    }

    var executionError: NSDictionary?
    let descriptor = script.executeAndReturnError(&executionError)
    let completedAt = Date()

    if let executionError {
      return failureResult(
        requestID: requestID,
        startedAt: startedAt,
        completedAt: completedAt,
        error: executionError,
        fallbackMessage: "AppleScript execution failed."
      )
    }

    return ScriptExecutionResult(
      requestID: requestID,
      status: .completed,
      sourceResultDescription: descriptor.flatMap { script.richText(from: $0)?.string },
      rawResultDescription: descriptor?.description,
      errorNumber: nil,
      errorMessage: nil,
      errorBriefMessage: nil,
      errorRange: nil,
      executionDuration: completedAt.timeIntervalSince(startedAt),
      startedAt: startedAt,
      completedAt: completedAt
    )
  }

  private func failureResult(
    requestID: UUID,
    startedAt: Date,
    completedAt: Date = Date(),
    error: NSDictionary?,
    fallbackMessage: String
  ) -> ScriptExecutionResult {
    let range = (error?[OSAScriptErrorRange] as? NSValue)?.rangeValue
    return ScriptExecutionResult(
      requestID: requestID,
      status: .failed,
      sourceResultDescription: nil,
      rawResultDescription: nil,
      errorNumber: (error?[OSAScriptErrorNumber] as? NSNumber)?.intValue,
      errorMessage: error?[OSAScriptErrorMessage] as? String ?? fallbackMessage,
      errorBriefMessage: error?[OSAScriptErrorBriefMessage] as? String,
      errorRange: range.map { ScriptSourceRange(location: $0.location, length: $0.length) },
      executionDuration: completedAt.timeIntervalSince(startedAt),
      startedAt: startedAt,
      completedAt: completedAt
    )
  }
}
