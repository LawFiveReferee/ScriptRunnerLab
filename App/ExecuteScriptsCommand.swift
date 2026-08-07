import AppKit
import Foundation
import ScriptRunnerKit

@objc(ExecuteScriptsCommand)
final class ExecuteScriptsCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    guard let directoryURL = directoryURL() else {
      scriptErrorNumber = NSArgumentsWrongScriptError
      scriptErrorString = "The in parameter must identify a directory."
      return nil
    }

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      scriptErrorNumber = NSArgumentEvaluationScriptError
      scriptErrorString = "The specified scripts directory does not exist."
      return nil
    }

    let mode = executionMode()
    if mode == .automatically {
      suspendExecution()
      Task { @MainActor [weak self] in
        guard let self else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        let accepted = ScriptRunnerModel.shared.executeScripts(
          in: directoryURL,
          mode: mode
        ) { [weak self] report in
          self?.resumeExecution(withResult: report)
        }
        if !accepted {
          resumeExecution(withResult: "The execution request could not be started.")
        }
      }
      return nil
    }

    Task { @MainActor in
      NSApplication.shared.activate(ignoringOtherApps: true)
      NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
      ScriptRunnerModel.shared.executeScripts(in: directoryURL, mode: mode)
    }
    return "Accepted interactive execution request for \(directoryURL.path)."
  }

  private func directoryURL() -> URL? {
    let descriptor = appleEvent?.paramDescriptor(forKeyword: keyDirectObject)
    if let url = descriptor?.fileURLValue { return url }
    if let value = directParameter as? URL { return value }
    if let value = directParameter as? NSURL { return value as URL }
    if let path = directParameter as? String { return URL(fileURLWithPath: path) }
    return nil
  }

  private func executionMode() -> ScriptCollectionExecutionMode {
    appleEvent?.eventID == Self.interactiveEventID ? .interactively : .automatically
  }

  private static let interactiveEventID: AEEventID = 0x496E5363 // InSc
}
