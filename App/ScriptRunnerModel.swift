import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ScriptRunnerModel {
  var descriptor: ScriptDescriptor?
  var result: ScriptExecutionResult?
  var status = ScriptExecutionStatus.ready
  var isRunning = false

  var canRun: Bool {
    descriptor?.scriptType != .unsupported && !isRunning
  }

  var durationText: String {
    guard let result else { return "" }
    return result.executionDuration.formatted(.number.precision(.fractionLength(3))) + " s"
  }

  var outputText: String {
    guard let result else { return "Results and errors will appear here." }
    if result.status == .completed {
      return result.resultDescription ?? "Script completed without a result."
    }

    var lines = [result.errorMessage ?? "Unknown AppleScript error"]
    if let errorNumber = result.errorNumber {
      lines.append("Error number: \(errorNumber)")
    }
    if let range = result.errorRange {
      lines.append("Source range: \(range.location)–\(range.location + range.length)")
    }
    return lines.joined(separator: "\n")
  }

  var diagnosticsText: String {
    var lines = [
      "Engine: OSAKit",
      "Sandbox: disabled",
      "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "Architecture: \(architectureName)"
    ]
    if let descriptor {
      lines.append("UTI: \(descriptor.typeIdentifier ?? "Unknown")")
      lines.append("Original URL preserved: yes")
    }
    if let result {
      lines.append("Request ID: \(result.requestID.uuidString)")
      lines.append("Started: \(result.startedAt.formatted(.iso8601))")
      lines.append("Completed: \(result.completedAt.formatted(.iso8601))")
      if let rawResultDescription = result.rawResultDescription {
        lines.append("Raw result: \(rawResultDescription)")
      }
    }
    return lines.joined(separator: "\n")
  }

  func receiveSelection(_ selection: Result<[URL], any Error>) {
    do {
      guard let url = try selection.get().first else { return }
      descriptor = ScriptDescriptor(url: url)
      result = nil
      status = .ready
    } catch {
      showLocalError(error.localizedDescription)
    }
  }

  func run() {
    guard let descriptor, canRun else { return }
    isRunning = true
    status = .running

    let accessed = descriptor.url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        descriptor.url.stopAccessingSecurityScopedResource()
      }
    }

    result = OSAKitRunner().execute(url: descriptor.url)
    status = result?.status ?? .failed
    isRunning = false
  }

  func revealScript() {
    guard let url = descriptor?.url else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func openInScriptEditor() {
    guard let url = descriptor?.url,
          let scriptEditorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ScriptEditor2") else {
      return
    }
    NSWorkspace.shared.open(
      [url],
      withApplicationAt: scriptEditorURL,
      configuration: NSWorkspace.OpenConfiguration()
    )
  }

  func copyResult() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(outputText, forType: .string)
  }

  func clearResult() {
    result = nil
    status = .ready
  }

  private var architectureName: String {
    #if arch(arm64)
    "Apple Silicon"
    #elseif arch(x86_64)
    "Intel"
    #else
    "Unknown"
    #endif
  }

  private func showLocalError(_ message: String) {
    let now = Date()
    result = ScriptExecutionResult(
      requestID: UUID(),
      status: .failed,
      resultDescription: nil,
      rawResultDescription: nil,
      errorNumber: nil,
      errorMessage: message,
      errorBriefMessage: nil,
      errorRange: nil,
      executionDuration: 0,
      startedAt: now,
      completedAt: now
    )
    status = .failed
  }
}
