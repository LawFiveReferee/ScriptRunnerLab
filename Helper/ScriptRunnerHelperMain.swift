import AppKit
import Darwin
import Dispatch
import Foundation
import ScriptRunnerKit

@main
enum ScriptRunnerHelperMain {
  static func main() {
    let application = NSApplication.shared
    let delegate = ScriptRunnerHelperDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
  }
}

@MainActor
private final class ScriptRunnerHelperDelegate: NSObject, NSApplicationDelegate {
  private var appletApplication: NSRunningApplication?
  private var appletStartedAt = Date()
  private var activeRequestID = UUID()
  private var accessedAppletURL: URL?
  private var resultURL: URL?
  private var terminationObserver: NSObjectProtocol?
  private var terminationSignalSource: DispatchSourceSignal?

  func applicationDidFinishLaunching(_ notification: Notification) {
    DispatchQueue.main.async {
      self.executeRequest()
    }
  }

  private func executeRequest() {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else {
      NSApplication.shared.terminate(nil)
      return
    }

    let requestURL = URL(fileURLWithPath: arguments[1])
    let resultURL = URL(fileURLWithPath: arguments[2])
    self.resultURL = resultURL

    do {
      let requestData = try Data(contentsOf: requestURL)
      let request = try JSONDecoder().decode(ScriptExecutionRequest.self, from: requestData)
      activeRequestID = request.requestID
      let scriptURL = try request.resolveScriptURL()
      if ScriptDescriptor(url: scriptURL).scriptType == .appleScriptApplet {
        launchApplet(at: scriptURL)
        return
      }

      let result = OSAKitRunner().execute(request: request)
      try write(result, to: resultURL)
    } catch {
      let result = ScriptExecutionResult.failure(
        requestID: UUID(),
        message: "ScriptRunnerHelper failed to process the request. \(error.localizedDescription)"
      )
      try? write(result, to: resultURL)
    }

    NSApplication.shared.terminate(nil)
  }

  private func launchApplet(at url: URL) {
    appletStartedAt = Date()
    if url.startAccessingSecurityScopedResource() {
      accessedAppletURL = url
    }
    installTerminationSignalHandler()

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.addsToRecentItems = false
    configuration.createsNewApplicationInstance = true
    configuration.promptsUserIfNeeded = true

    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] application, error in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let error {
          self.finishApplet(
            with: .failure(
              requestID: self.activeRequestID,
              message: "The AppleScript applet could not be launched. \(error.localizedDescription)",
              startedAt: self.appletStartedAt
            )
          )
          return
        }
        guard let application else {
          self.finishApplet(
            with: .failure(
              requestID: self.activeRequestID,
              message: "The AppleScript applet could not be launched.",
              startedAt: self.appletStartedAt
            )
          )
          return
        }

        self.appletApplication = application
        self.observeAppletTermination(application)
        if application.isTerminated {
          self.appletDidTerminate(application)
        }
      }
    }
  }

  private func observeAppletTermination(_ application: NSRunningApplication) {
    terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let terminatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
        as? NSRunningApplication else {
        return
      }
      Task { @MainActor [weak self] in
        guard terminatedApplication == application else { return }
        self?.appletDidTerminate(terminatedApplication)
      }
    }
  }

  private func appletDidTerminate(_ application: NSRunningApplication) {
    guard appletApplication == application else { return }
    let completedAt = Date()
    finishApplet(
      with: ScriptExecutionResult(
        requestID: activeRequestID,
        status: .completed,
        sourceResultDescription: "Applet completed successfully.",
        rawResultDescription: "Applet launch does not return an Apple Event result.",
        errorNumber: nil,
        errorMessage: nil,
        errorBriefMessage: nil,
        errorRange: nil,
        executionDuration: completedAt.timeIntervalSince(appletStartedAt),
        startedAt: appletStartedAt,
        completedAt: completedAt
      )
    )
  }

  private func installTerminationSignalHandler() {
    signal(SIGTERM, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    source.setEventHandler { [weak self] in
      self?.appletApplication?.forceTerminate()
      NSApplication.shared.terminate(nil)
    }
    source.resume()
    terminationSignalSource = source
  }

  private func finishApplet(with result: ScriptExecutionResult) {
    guard let resultURL else {
      NSApplication.shared.terminate(nil)
      return
    }
    try? write(result, to: resultURL)
    cleanUpApplet()
    NSApplication.shared.terminate(nil)
  }

  private func cleanUpApplet() {
    if let terminationObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
      self.terminationObserver = nil
    }
    if let accessedAppletURL {
      accessedAppletURL.stopAccessingSecurityScopedResource()
      self.accessedAppletURL = nil
    }
    terminationSignalSource?.cancel()
    terminationSignalSource = nil
    appletApplication = nil
  }

  private func write(_ result: ScriptExecutionResult, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(result).write(to: url, options: .atomic)
  }
}
