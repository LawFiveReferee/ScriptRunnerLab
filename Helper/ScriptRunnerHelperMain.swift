import AppKit
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

    do {
      let requestData = try Data(contentsOf: requestURL)
      let request = try JSONDecoder().decode(ScriptExecutionRequest.self, from: requestData)
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

  private func write(_ result: ScriptExecutionResult, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(result).write(to: url, options: .atomic)
  }
}
