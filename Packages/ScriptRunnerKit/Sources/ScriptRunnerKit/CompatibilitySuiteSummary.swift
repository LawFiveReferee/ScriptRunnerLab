import Foundation

public struct CompatibilitySuiteSummary: Codable, Sendable {
  public var schemaVersion: Int
  public var suiteName: String
  public var generatedAt: Date
  public var startedAt: Date?
  public var completedAt: Date?
  public var host: ScriptExecutionLogEntry.Host
  public var environment: ScriptExecutionLogEntry.Environment
  public var engineDescription: String
  public var executionLogPath: String?
  public var automaticTestCount: Int
  public var contentAssertionCount: Int
  public var passedCount: Int
  public var failedCount: Int
  public var entries: [CompatibilitySuiteSummaryEntry]
  public var deferredTests: [CompatibilitySuiteDeferredTest]

  public init(
    schemaVersion: Int = 1,
    suiteName: String,
    generatedAt: Date = Date(),
    startedAt: Date?,
    completedAt: Date?,
    configuration: ScriptRunnerHostConfiguration,
    engineDescription: String = "OSAKit and NSWorkspace applet launch",
    automaticTests: [CompatibilityTestDefinition],
    results: [String: CompatibilityTestResult],
    deferredTests: [CompatibilityTestDefinition]
  ) {
    self.schemaVersion = schemaVersion
    self.suiteName = suiteName
    self.generatedAt = generatedAt
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.host = configuration.host
    self.environment = configuration.environment
    self.engineDescription = engineDescription
    self.executionLogPath = configuration.logURL?.path(percentEncoded: false)
    self.automaticTestCount = automaticTests.count
    self.contentAssertionCount = automaticTests.reduce(0) {
      $0 + ($1.expectedOutcome?.assertions.count ?? 0)
    }
    self.passedCount = results.values.filter { $0.state == .passed }.count
    self.failedCount = results.values.filter { $0.state == .failed }.count
    self.entries = automaticTests.map { test in
      CompatibilitySuiteSummaryEntry(
        relativePath: test.relativePath,
        expectedDescription: test.expectedOutcome?.summaryDescription,
        result: results[test.id]
      )
    }
    self.deferredTests = deferredTests.map { test in
      CompatibilitySuiteDeferredTest(
        relativePath: test.relativePath,
        disposition: test.disposition.displayName,
        reason: test.disposition.reason
      )
    }
  }

  public var text: String {
    var lines = [
      suiteName,
      "Version: \(host.version ?? "Unknown") (\(host.build ?? "Unknown"))",
      "Generated: \(generatedAt.formatted(.iso8601))",
      "Started: \(startedAt?.formatted(.iso8601) ?? "Not recorded")",
      "Completed: \(completedAt?.formatted(.iso8601) ?? "Not completed")",
      "Engine: \(engineDescription)",
      "Isolation: \(environment.isolation)",
      "Sandbox: \(environment.isSandboxed ? "enabled" : "disabled")",
      "macOS: \(environment.operatingSystem)",
      "Architecture: \(environment.architecture)",
      "Execution log: \(executionLogPath ?? "Not configured")",
      "Automatic tests: \(automaticTestCount)",
      "Content assertions: \(contentAssertionCount)",
      "Passed: \(passedCount)",
      "Failed: \(failedCount)",
      ""
    ]
    lines.append(contentsOf: entries.map(\.text))
    lines.append("")
    lines.append("Manual and optional tests not run automatically:")
    lines.append(contentsOf: deferredTests.map(\.text))
    return lines.joined(separator: "\n")
  }

  public func jsonData(prettyPrinted: Bool = true) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    return try encoder.encode(self)
  }
}

public struct CompatibilitySuiteSummaryEntry: Codable, Sendable {
  public var relativePath: String
  public var expectedDescription: String?
  public var state: CompatibilityTestRunState?
  public var observedStatus: ScriptExecutionStatus?
  public var errorNumber: Int?
  public var message: String?
  public var duration: TimeInterval?

  public init(
    relativePath: String,
    expectedDescription: String?,
    result: CompatibilityTestResult?
  ) {
    self.relativePath = relativePath
    self.expectedDescription = expectedDescription
    self.state = result?.state
    self.observedStatus = result?.observedStatus
    self.errorNumber = result?.errorNumber
    self.message = result?.message
    self.duration = result?.duration
  }

  public var text: String {
    var detail = "[\(state?.displayName.uppercased() ?? "NOT RUN")] \(relativePath)"
    if let expectedDescription {
      detail += " — expected: \(expectedDescription)"
    }
    if let observedStatus {
      detail += " — observed: \(observedStatus.displayName)"
    }
    if let errorNumber {
      detail += " (\(errorNumber))"
    }
    if let message, !message.isEmpty {
      detail += " — \(message)"
    }
    if let duration {
      detail += " — \(duration.formatted(.number.precision(.fractionLength(3)))) s"
    }
    return detail
  }
}

public struct CompatibilitySuiteDeferredTest: Codable, Sendable {
  public var relativePath: String
  public var disposition: String
  public var reason: String?

  public init(relativePath: String, disposition: String, reason: String?) {
    self.relativePath = relativePath
    self.disposition = disposition
    self.reason = reason
  }

  public var text: String {
    "[\(disposition.uppercased())] \(relativePath) — \(reason ?? "")"
  }
}
