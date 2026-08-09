import Darwin
import Foundation

@MainActor
public final class ScriptHelperProcessRunner {
  private var process: Process?
  private var helperExecutableURL: URL
  private var workingDirectoryRoot: URL

  public init(
    helperExecutableURL: URL,
    temporaryDirectory: URL = FileManager.default.temporaryDirectory,
    workingDirectoryName: String = "ScriptRunnerKit"
  ) {
    self.helperExecutableURL = helperExecutableURL
    self.workingDirectoryRoot = temporaryDirectory.appending(
      path: workingDirectoryName,
      directoryHint: .isDirectory
    )
  }

  public func execute(
    request: ScriptExecutionRequest,
    timeout: TimeInterval,
    progressHandler: @escaping (ScriptProgressSnapshot) -> Void = { _ in }
  ) async throws -> ScriptExecutionResult {
    guard FileManager.default.isExecutableFile(atPath: helperExecutableURL.path) else {
      throw ScriptHelperProcessError.helperMissing
    }

    let workingDirectory = workingDirectoryRoot.appending(
      path: request.requestID.uuidString,
      directoryHint: .isDirectory
    )
    let requestURL = workingDirectory.appending(path: "request.json")
    let resultURL = workingDirectory.appending(path: "result.json")
    let progressURL = workingDirectory.appending(path: "progress.json")
    try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: workingDirectory)
      process = nil
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(request).write(to: requestURL, options: .atomic)

    let process = Process()
    process.executableURL = helperExecutableURL
    process.arguments = [requestURL.path, resultURL.path, progressURL.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    self.process = process
    try process.run()

    let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
    var lastProgressUpdate: Date?
    do {
      while process.isRunning {
        if var snapshot = readProgress(at: progressURL), snapshot.updatedAt != lastProgressUpdate {
          lastProgressUpdate = snapshot.updatedAt
          snapshot.scriptIdentity = request.identity
          progressHandler(snapshot)
        }
        try Task.checkCancellation()
        if ContinuousClock.now >= deadline {
          await stop(process)
          throw ScriptHelperProcessError.timedOut
        }
        try await Task.sleep(for: .milliseconds(50))
      }
      try Task.checkCancellation()
    } catch is CancellationError {
      await stop(process)
      throw ScriptHelperProcessError.cancelled
    }

    if let data = try? Data(contentsOf: resultURL),
       let result = try? JSONDecoder().decode(ScriptExecutionResult.self, from: data) {
      return result
    }
    throw ScriptHelperProcessError.exitedWithoutResult(process.terminationStatus)
  }

  public func cancel() {
    process?.terminate()
  }

  private func readProgress(at url: URL) -> ScriptProgressSnapshot? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(ScriptProgressSnapshot.self, from: data)
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

public enum ScriptHelperProcessError: LocalizedError, Equatable, Sendable {
  case helperMissing
  case timedOut
  case cancelled
  case exitedWithoutResult(Int32)

  public var errorDescription: String? {
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
