import Foundation
import OSAKit

public struct OSAKitRunner {
  public init() {}

  public func execute(
    request: ScriptExecutionRequest,
    progressHandler: ((ScriptProgressSnapshot) -> Void)? = nil
  ) -> ScriptExecutionResult {
    let startedAt = Date()

    do {
      let url = try request.resolveScriptURL()
      let accessed = url.startAccessingSecurityScopedResource()
      defer {
        if accessed {
          url.stopAccessingSecurityScopedResource()
        }
      }
      return execute(
        url: url,
        requestID: request.requestID,
        startedAt: startedAt,
        progressHandler: progressHandler
      )
    } catch {
      return .failure(
        requestID: request.requestID,
        message: "The helper could not access the selected script. \(error.localizedDescription)",
        startedAt: startedAt
      )
    }
  }

  public func execute(
    url: URL,
    requestID: UUID = UUID(),
    startedAt: Date = Date(),
    progressHandler: ((ScriptProgressSnapshot) -> Void)? = nil
  ) -> ScriptExecutionResult {
    var loadError: NSDictionary?

    guard let script = OSAScript(contentsOf: url, error: &loadError) else {
      return failureResult(
        requestID: requestID,
        startedAt: startedAt,
        error: loadError,
        fallbackMessage: "OSAKit could not load this script."
      )
    }

    if !script.isCompiled {
      var compileError: NSDictionary?
      guard script.compileAndReturnError(&compileError) else {
        return failureResult(
          requestID: requestID,
          startedAt: startedAt,
          error: compileError,
          fallbackMessage: "AppleScript compilation failed.",
          status: .compileError
        )
      }
    }

    let preparedProgress = progressHandler.flatMap {
      AppleScriptProgressBridge.prepare(
        script: script,
        originalURL: url,
        requestID: requestID,
        handler: $0
      )
    }
    let executionScript = preparedProgress?.script ?? script
    preparedProgress?.bridge.start()
    defer { preparedProgress?.bridge.stop() }

    var executionError: NSDictionary?
    let descriptor = executionScript.executeAndReturnError(&executionError)
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
      sourceResultDescription: descriptor.flatMap { executionScript.richText(from: $0)?.string },
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
    fallbackMessage: String,
    status: ScriptExecutionStatus = .failed
  ) -> ScriptExecutionResult {
    let range = (error?[OSAScriptErrorRange] as? NSValue)?.rangeValue
    return ScriptExecutionResult(
      requestID: requestID,
      status: status,
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
