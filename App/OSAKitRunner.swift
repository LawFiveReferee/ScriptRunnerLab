import Foundation
import OSAKit

struct OSAKitRunner {
  func execute(url: URL) -> ScriptExecutionResult {
    let requestID = UUID()
    let startedAt = Date()
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
    ScriptExecutionResult(
      requestID: requestID,
      status: .failed,
      sourceResultDescription: nil,
      rawResultDescription: nil,
      errorNumber: (error?[OSAScriptErrorNumber] as? NSNumber)?.intValue,
      errorMessage: error?[OSAScriptErrorMessage] as? String ?? fallbackMessage,
      errorBriefMessage: error?[OSAScriptErrorBriefMessage] as? String,
      errorRange: (error?[OSAScriptErrorRange] as? NSValue)?.rangeValue,
      executionDuration: completedAt.timeIntervalSince(startedAt),
      startedAt: startedAt,
      completedAt: completedAt
    )
  }
}
