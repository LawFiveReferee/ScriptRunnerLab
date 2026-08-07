import Foundation

public struct CompatibilityTestDefinition: Identifiable, Sendable {
  public var relativePath: String
  public var displayName: String
  public var disposition: CompatibilityTestDisposition
  public var expectedOutcome: CompatibilityExpectedOutcome?
  public var timeout: TimeInterval

  public var id: String { relativePath }

  public init(
    relativePath: String,
    displayName: String,
    disposition: CompatibilityTestDisposition,
    expectedOutcome: CompatibilityExpectedOutcome?,
    timeout: TimeInterval
  ) {
    self.relativePath = relativePath
    self.displayName = displayName
    self.disposition = disposition
    self.expectedOutcome = expectedOutcome
    self.timeout = timeout
  }

  public static let all: [CompatibilityTestDefinition] = [
    automatic(
      "Sources/01-Core/BasicReturn.applescript",
      expected: .completed(sourceEquals: "\"Hello from ScriptRunnerLab\"")
    ),
    automatic(
      "Sources/01-Core/HandlerRun.applescript",
      expected: .completed(sourceEquals: "\"Handler OK\"")
    ),
    automatic(
      "Sources/01-Core/IntentionalRuntimeError.applescript",
      expected: .status(
        .failed,
        errorNumber: -2700,
        assertions: [.errorMessageEquals("Intentional ScriptRunnerLab runtime error"), .hasSourceRange]
      )
    ),
    automatic(
      "Sources/01-Core/IntentionalSyntaxError.applescript",
      expected: .status(
        .compileError,
        errorNumber: -2741,
        assertions: [.errorMessageEquals("Expected “\"” but found end of script."), .hasSourceRange]
      )
    ),
    automatic(
      "Sources/01-Core/LargeResult.applescript",
      expected: .completed(sourceEquals: "{" + (1...1000).map(String.init).joined(separator: ", ") + "}")
    ),
    automatic(
      "Sources/01-Core/PathToMe.applescript",
      expected: .completed(sourceContains: "PathToMe.applescript")
    ),
    automatic(
      "Sources/01-Core/ResultTypes.applescript",
      expected: .completed(
        sourceEquals: "{message:\"Hello\", integerValue:42, realValue:3.5, booleanValue:true, emptyValue:missing value, nestedValues:{\"alpha\", 2, false}}"
      )
    ),
    automatic(
      "Sources/01-Core/UnicodeAndMultiline.applescript",
      expected: .completed(sourceEquals: "\"Café — 日本語 — مرحبًا\rSecond line\nThird line\"")
    ),
    manual(
      "Sources/02-Isolation/DelayForCancellation.applescript",
      reason: "Requires the user to press Cancel during execution."
    ),
    manual(
      "Sources/02-Isolation/InfiniteLoop.applescript",
      reason: "Requires an intentional timeout."
    ),
    manual(
      "Sources/03-Automation/AccessibilityProbe.applescript",
      reason: "May request Accessibility permission."
    ),
    manual(
      "Sources/03-Automation/FinderAutomation.applescript",
      reason: "May request Finder Automation permission."
    ),
    automatic(
      "Sources/03-Automation/MissingApplication.applescript",
      expected: .status(
        .compileError,
        errorNumber: -1728,
        assertions: [.errorMessageContains("org.scriptrunnerlab.missing-application"), .hasSourceRange]
      )
    ),
    manual(
      "Sources/03-Automation/MultipleApplications.applescript",
      reason: "May request Automation permission for multiple applications."
    ),
    automatic(
      "Sources/04-UI/BuiltInProgress.applescript",
      expected: .completed(sourceEquals: "\"Built-in progress completed\""),
      timeout: 20
    ),
    automatic(
      "Sources/04-UI/ShellCommand.applescript",
      expected: .completed(sourceEquals: "\"Shell command OK\"")
    ),
    manual("Sources/04-UI/StandardDialog.applescript", reason: "Requires a dialog response."),
    manual("Sources/04-UI/UserCancellation.applescript", reason: "Requires the user to cancel a dialog."),
    automatic(
      "Sources/05-AppleScriptObjC/AppKit.applescript",
      expected: .completed(sourceIntegerAtLeast: 1)
    ),
    automatic(
      "Sources/05-AppleScriptObjC/Foundation.applescript",
      expected: .completed(sourceEquals: "\"SCRIPTRUNNERLAB\"")
    ),
    automatic(
      "Sources/05-AppleScriptObjC/FoundationFileIO.applescript",
      expected: .completed(sourceEquals: "\"Foundation file IO OK\"")
    ),
    optional("Sources/06-Libraries/BridgePlus.applescript", reason: "Requires BridgePlus to be installed."),
    optional(
      "Sources/06-Libraries/DialogToolkitPlus.applescript",
      reason: "Requires Dialog Toolkit Plus to be installed."
    ),
    automatic(
      "Sources/06-Libraries/MissingLibrary.applescript",
      expected: .status(
        .compileError,
        errorNumber: -1728,
        assertions: [.errorMessageContains("ScriptRunnerLab Missing Library Fixture"), .hasSourceRange]
      )
    ),
    optional(
      "Sources/06-Libraries/MyriadTables.applescript",
      reason: "Requires Myriad Tables and user interaction."
    ),
    optional("Sources/06-Libraries/SQLiteLib2.applescript", reason: "Requires SQLite Lib2 to be installed."),
    automatic(
      "Sources/08-Persistence/PersistentProperty.applescript",
      expected: .completed(sourceEquals: "1")
    ),
    automatic("Artifacts/BasicReturn.scpt", expected: .completed(sourceEquals: "\"Hello from ScriptRunnerLab\"")),
    automatic("Artifacts/PersistentProperty.scpt", expected: .completed(sourceEquals: "1")),
    automatic(
      "Artifacts/BundleResource.scptd",
      expected: .completed(
        assertions: [
          .sourceContains("resourceContents:\"Bundled resource OK"),
          .sourceContains("scriptLocation:"),
          .sourceContains("BundleResource.scptd")
        ]
      )
    ),
    automatic(
      "Artifacts/BasicReturnApplet.app",
      expected: .completed(sourceEquals: "Applet completed successfully."),
      timeout: 20
    ),
    manual(
      "Artifacts/AppletLifecycle.app",
      reason: "Stays open until the user cancels it or a timeout is selected."
    )
  ]

  public static var automaticTests: [CompatibilityTestDefinition] {
    all.filter { $0.disposition == .automatic }
  }

  public static var deferredTests: [CompatibilityTestDefinition] {
    all.filter { $0.disposition != .automatic }
  }

  private static func automatic(
    _ path: String,
    expected: CompatibilityExpectedOutcome = .completed,
    timeout: TimeInterval = 10
  ) -> CompatibilityTestDefinition {
    CompatibilityTestDefinition(
      relativePath: path,
      displayName: URL(fileURLWithPath: path).lastPathComponent,
      disposition: .automatic,
      expectedOutcome: expected,
      timeout: timeout
    )
  }

  private static func manual(_ path: String, reason: String) -> CompatibilityTestDefinition {
    CompatibilityTestDefinition(
      relativePath: path,
      displayName: URL(fileURLWithPath: path).lastPathComponent,
      disposition: .manual(reason: reason),
      expectedOutcome: nil,
      timeout: 0
    )
  }

  private static func optional(_ path: String, reason: String) -> CompatibilityTestDefinition {
    CompatibilityTestDefinition(
      relativePath: path,
      displayName: URL(fileURLWithPath: path).lastPathComponent,
      disposition: .optional(reason: reason),
      expectedOutcome: nil,
      timeout: 0
    )
  }
}

public enum CompatibilityTestDisposition: Equatable, Sendable {
  case automatic
  case manual(reason: String)
  case optional(reason: String)

  public var displayName: String {
    switch self {
    case .automatic: "Automatic"
    case .manual: "Manual"
    case .optional: "Optional"
    }
  }

  public var reason: String? {
    switch self {
    case .automatic: nil
    case .manual(let reason), .optional(let reason): reason
    }
  }
}

public struct CompatibilityExpectedOutcome: Sendable {
  public var status: ScriptExecutionStatus
  public var errorNumber: Int?
  public var assertions: [CompatibilityResultAssertion]

  public init(
    status: ScriptExecutionStatus,
    errorNumber: Int?,
    assertions: [CompatibilityResultAssertion]
  ) {
    self.status = status
    self.errorNumber = errorNumber
    self.assertions = assertions
  }

  public static let completed = CompatibilityExpectedOutcome(status: .completed, errorNumber: nil, assertions: [])

  public static func completed(sourceEquals value: String) -> CompatibilityExpectedOutcome {
    completed(assertions: [.sourceEquals(value)])
  }

  public static func completed(sourceContains value: String) -> CompatibilityExpectedOutcome {
    completed(assertions: [.sourceContains(value)])
  }

  public static func completed(sourceIntegerAtLeast value: Int) -> CompatibilityExpectedOutcome {
    completed(assertions: [.sourceIntegerAtLeast(value)])
  }

  public static func completed(
    assertions: [CompatibilityResultAssertion]
  ) -> CompatibilityExpectedOutcome {
    CompatibilityExpectedOutcome(status: .completed, errorNumber: nil, assertions: assertions)
  }

  public static func status(
    _ status: ScriptExecutionStatus,
    errorNumber: Int? = nil,
    assertions: [CompatibilityResultAssertion] = []
  ) -> CompatibilityExpectedOutcome {
    CompatibilityExpectedOutcome(status: status, errorNumber: errorNumber, assertions: assertions)
  }

  public func failures(for result: ScriptExecutionResult) -> [String] {
    var failures: [String] = []
    if result.status != status {
      failures.append("expected \(status.displayName), observed \(result.status.displayName)")
    }
    if let errorNumber, result.errorNumber != errorNumber {
      failures.append("expected error \(errorNumber), observed \(result.errorNumber.map(String.init) ?? "none")")
    }
    failures.append(contentsOf: assertions.compactMap { $0.failure(for: result) })
    return failures
  }

  public var displayName: String {
    if let errorNumber {
      return "\(status.displayName) (\(errorNumber)) + \(assertions.count) assertion(s)"
    }
    if assertions.isEmpty { return status.displayName }
    return "\(status.displayName) + \(assertions.count) assertion(s)"
  }

  public var summaryDescription: String {
    var components = [errorNumber.map { "\(status.displayName) (\($0))" } ?? status.displayName]
    components.append(contentsOf: assertions.map(\.summaryDescription))
    return components.joined(separator: "; ")
  }
}

public enum CompatibilityResultAssertion: Sendable {
  case sourceEquals(String)
  case sourceContains(String)
  case sourceIntegerAtLeast(Int)
  case errorMessageEquals(String)
  case errorMessageContains(String)
  case hasSourceRange

  public var summaryDescription: String {
    switch self {
    case .sourceEquals(let expected):
      expected.count > 120
        ? "source equals an exact \(expected.count)-character value"
        : "source equals \(expected.debugDescription)"
    case .sourceContains(let expected): "source contains \(expected.debugDescription)"
    case .sourceIntegerAtLeast(let minimum): "source is an integer ≥ \(minimum)"
    case .errorMessageEquals(let expected): "error message equals \(expected.debugDescription)"
    case .errorMessageContains(let expected): "error message contains \(expected.debugDescription)"
    case .hasSourceRange: "structured source range is present"
    }
  }

  public func failure(for result: ScriptExecutionResult) -> String? {
    switch self {
    case .sourceEquals(let expected):
      guard result.sourceResultDescription == expected else { return "source result did not exactly match" }
    case .sourceContains(let expected):
      guard result.sourceResultDescription?.contains(expected) == true else {
        return "source result did not contain \(expected.debugDescription)"
      }
    case .sourceIntegerAtLeast(let minimum):
      guard let source = result.sourceResultDescription, let value = Int(source), value >= minimum else {
        return "source result was not an integer of at least \(minimum)"
      }
    case .errorMessageEquals(let expected):
      guard result.errorMessage == expected else { return "error message did not exactly match" }
    case .errorMessageContains(let expected):
      guard result.errorMessage?.contains(expected) == true else {
        return "error message did not contain \(expected.debugDescription)"
      }
    case .hasSourceRange:
      guard result.errorRange != nil else { return "structured source range was missing" }
    }
    return nil
  }
}
