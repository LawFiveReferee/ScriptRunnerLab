import Foundation
import ScriptRunnerKit

struct CompatibilityTestDefinition: Identifiable, Sendable {
  var relativePath: String
  var displayName: String
  var disposition: CompatibilityTestDisposition
  var expectedOutcome: CompatibilityExpectedOutcome?
  var timeout: TimeInterval

  var id: String { relativePath }

  static let all: [CompatibilityTestDefinition] = [
    automatic("Sources/01-Core/BasicReturn.applescript"),
    automatic("Sources/01-Core/HandlerRun.applescript"),
    automatic(
      "Sources/01-Core/IntentionalRuntimeError.applescript",
      expected: .status(.failed, errorNumber: -2700)
    ),
    automatic(
      "Sources/01-Core/IntentionalSyntaxError.applescript",
      expected: .status(.compileError, errorNumber: -2741)
    ),
    automatic("Sources/01-Core/LargeResult.applescript"),
    automatic("Sources/01-Core/PathToMe.applescript"),
    automatic("Sources/01-Core/ResultTypes.applescript"),
    automatic("Sources/01-Core/UnicodeAndMultiline.applescript"),
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
      expected: .failure
    ),
    manual(
      "Sources/03-Automation/MultipleApplications.applescript",
      reason: "May request Automation permission for multiple applications."
    ),
    automatic("Sources/04-UI/BuiltInProgress.applescript", timeout: 20),
    automatic("Sources/04-UI/ShellCommand.applescript"),
    manual(
      "Sources/04-UI/StandardDialog.applescript",
      reason: "Requires a dialog response."
    ),
    manual(
      "Sources/04-UI/UserCancellation.applescript",
      reason: "Requires the user to cancel a dialog."
    ),
    automatic("Sources/05-AppleScriptObjC/AppKit.applescript"),
    automatic("Sources/05-AppleScriptObjC/Foundation.applescript"),
    automatic("Sources/05-AppleScriptObjC/FoundationFileIO.applescript"),
    optional(
      "Sources/06-Libraries/BridgePlus.applescript",
      reason: "Requires BridgePlus to be installed."
    ),
    optional(
      "Sources/06-Libraries/DialogToolkitPlus.applescript",
      reason: "Requires Dialog Toolkit Plus to be installed."
    ),
    automatic("Sources/06-Libraries/MissingLibrary.applescript", expected: .failure),
    optional(
      "Sources/06-Libraries/MyriadTables.applescript",
      reason: "Requires Myriad Tables and user interaction."
    ),
    optional(
      "Sources/06-Libraries/SQLiteLib2.applescript",
      reason: "Requires SQLite Lib2 to be installed."
    ),
    automatic("Sources/08-Persistence/PersistentProperty.applescript"),
    automatic("Artifacts/BasicReturn.scpt"),
    automatic("Artifacts/PersistentProperty.scpt"),
    automatic("Artifacts/BundleResource.scptd"),
    automatic("Artifacts/BasicReturnApplet.app", timeout: 20),
    manual(
      "Artifacts/AppletLifecycle.app",
      reason: "Stays open until the user cancels it or a timeout is selected."
    )
  ]

  static var automaticTests: [CompatibilityTestDefinition] {
    all.filter { $0.disposition == .automatic }
  }

  static var deferredTests: [CompatibilityTestDefinition] {
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

enum CompatibilityTestDisposition: Equatable, Sendable {
  case automatic
  case manual(reason: String)
  case optional(reason: String)

  var displayName: String {
    switch self {
    case .automatic: "Automatic"
    case .manual: "Manual"
    case .optional: "Optional"
    }
  }

  var reason: String? {
    switch self {
    case .automatic: nil
    case .manual(let reason), .optional(let reason): reason
    }
  }
}

enum CompatibilityExpectedOutcome: Sendable {
  case completed
  case status(ScriptExecutionStatus, errorNumber: Int?)
  case failure

  func matches(_ result: ScriptExecutionResult) -> Bool {
    switch self {
    case .completed:
      result.status == .completed
    case .status(let status, let errorNumber):
      result.status == status && (errorNumber == nil || result.errorNumber == errorNumber)
    case .failure:
      result.status == .failed || result.status == .compileError
    }
  }

  var displayName: String {
    switch self {
    case .completed: "Completed"
    case .status(let status, let errorNumber):
      if let errorNumber {
        "\(status.displayName) (\(errorNumber))"
      } else {
        status.displayName
      }
    case .failure: "Expected Error"
    }
  }
}
