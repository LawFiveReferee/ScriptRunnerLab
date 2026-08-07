import Foundation

public extension ScriptRunnerService {
  func executeCompatibilitySuite(
    testsRootURL: URL,
    tests: [CompatibilityTestDefinition] = CompatibilityTestDefinition.automaticTests,
    testStarted: @escaping (CompatibilityTestDefinition) -> Void = { _ in },
    progressHandler: @escaping (CompatibilityTestDefinition, ScriptProgressSnapshot) -> Void = { _, _ in },
    testCompleted: @escaping (CompatibilityTestDefinition, CompatibilityTestResult) -> Void = { _, _ in }
  ) async -> CompatibilitySuiteReport {
    let startedAt = Date()
    var completion = CompatibilitySuiteCompletion.finished
    var entries: [CompatibilitySuiteEntry] = []

    for test in tests where test.disposition == .automatic {
      if Task.isCancelled {
        completion = .stopped
        break
      }
      testStarted(test)
      let scriptURL = testsRootURL.appending(path: test.relativePath)
      guard FileManager.default.fileExists(atPath: scriptURL.path) else {
        let testResult = CompatibilityTestResult(
          state: .failed,
          message: "The bundled test file is missing."
        )
        entries.append(CompatibilitySuiteEntry(test: test, result: testResult))
        testCompleted(test, testResult)
        continue
      }

      let executionResult = await execute(scriptURL: scriptURL, timeout: test.timeout) { snapshot in
        progressHandler(test, snapshot)
      }
      if executionResult.status == .cancelled, Task.isCancelled {
        let testResult = CompatibilityTestResult(
          state: .stopped,
          observedStatus: executionResult.status,
          errorNumber: executionResult.errorNumber,
          message: "The suite was stopped.",
          duration: executionResult.executionDuration
        )
        entries.append(CompatibilitySuiteEntry(test: test, result: testResult))
        testCompleted(test, testResult)
        completion = .stopped
        break
      }

      let failures = test.expectedOutcome?.failures(for: executionResult)
        ?? ["The test has no expected outcome."]
      let passed = failures.isEmpty
      let message = passed
        ? "Matched \(test.expectedOutcome?.displayName ?? executionResult.status.displayName)."
        : "Assertion mismatch: " + failures.joined(separator: "; ") + "."
      let testResult = CompatibilityTestResult(
        state: passed ? .passed : .failed,
        observedStatus: executionResult.status,
        errorNumber: executionResult.errorNumber,
        message: message,
        duration: executionResult.executionDuration
      )
      entries.append(CompatibilitySuiteEntry(test: test, result: testResult))
      testCompleted(test, testResult)
    }

    return CompatibilitySuiteReport(
      startedAt: startedAt,
      completedAt: Date(),
      completion: completion,
      entries: entries
    )
  }
}
