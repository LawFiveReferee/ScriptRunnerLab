import Darwin
import Foundation
import ScriptRunnerKit

@MainActor
final class HelperProcessRunner {
  private var process: Process?

  func execute(
    request: ScriptExecutionRequest,
    timeout: TimeInterval
  ) async throws -> ScriptExecutionResult {
    let workingDirectory = FileManager.default.temporaryDirectory
      .appending(path: "ScriptRunnerLab/\(request.requestID.uuidString)", directoryHint: .isDirectory)
    let requestURL = workingDirectory.appending(path: "request.json")
    let resultURL = workingDirectory.appending(path: "result.json")
    try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: workingDirectory)
      process = nil
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(request).write(to: requestURL, options: .atomic)

    let helperURL = try helperExecutableURL()
    let process = Process()
    process.executableURL = helperURL
    process.arguments = [requestURL.path, resultURL.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    self.process = process
    try process.run()

    let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
    do {
      while process.isRunning {
        try Task.checkCancellation()
        if ContinuousClock.now >= deadline {
          await stop(process)
          throw HelperProcessError.timedOut
        }
        try await Task.sleep(for: .milliseconds(50))
      }
      try Task.checkCancellation()
    } catch is CancellationError {
      await stop(process)
      throw HelperProcessError.cancelled
    }

    if let data = try? Data(contentsOf: resultURL),
       let result = try? JSONDecoder().decode(ScriptExecutionResult.self, from: data) {
      return result
    }

    throw HelperProcessError.exitedWithoutResult(process.terminationStatus)
  }

  func cancel() {
    process?.terminate()
  }

  private func helperExecutableURL() throws -> URL {
    let url = Bundle.main.bundleURL
      .appending(path: "Contents/Helpers/ScriptRunnerHelper.app/Contents/MacOS/ScriptRunnerHelper")
    guard FileManager.default.isExecutableFile(atPath: url.path) else {
      throw HelperProcessError.helperMissing
    }
    return url
  }

  private func stop(_ process: Process) async {
    if process.isRunning {
      process.terminate()
    }
    for _ in 0..<20 where process.isRunning {
      try? await Task.sleep(for: .milliseconds(50))
    }
    if process.isRunning {
      kill(process.processIdentifier, SIGKILL)
      for _ in 0..<20 where process.isRunning {
        try? await Task.sleep(for: .milliseconds(25))
      }
    }
  }
}

enum HelperProcessError: LocalizedError {
  case helperMissing
  case timedOut
  case cancelled
  case exitedWithoutResult(Int32)

  var errorDescription: String? {
    switch self {
    case .helperMissing:
      "ScriptRunnerHelper is missing from the application bundle."
    case .timedOut:
      "The script exceeded the selected timeout and was terminated."
    case .cancelled:
      "Script execution was cancelled."
    case .exitedWithoutResult(let status):
      "ScriptRunnerHelper exited without a result (status \(status))."
    }
  }
}
