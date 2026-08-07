import Foundation

public struct ScriptRunnerHostConfiguration: Sendable {
  public var helperExecutableURL: URL
  public var workingDirectoryName: String
  public var logURL: URL?
  public var host: ScriptExecutionLogEntry.Host
  public var environment: ScriptExecutionLogEntry.Environment

  public init(
    helperExecutableURL: URL,
    workingDirectoryName: String,
    logURL: URL?,
    host: ScriptExecutionLogEntry.Host,
    environment: ScriptExecutionLogEntry.Environment
  ) {
    self.helperExecutableURL = helperExecutableURL
    self.workingDirectoryName = workingDirectoryName
    self.logURL = logURL
    self.host = host
    self.environment = environment
  }

  public static func current(
    helperExecutableURL: URL,
    workingDirectoryName: String,
    logURL: URL?,
    bundle: Bundle = .main,
    displayNameFallback: String,
    isSandboxed: Bool = false,
    isolation: String = "ScriptRunnerHelper (one process per request)"
  ) -> ScriptRunnerHostConfiguration {
    ScriptRunnerHostConfiguration(
      helperExecutableURL: helperExecutableURL,
      workingDirectoryName: workingDirectoryName,
      logURL: logURL,
      host: .init(
        name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? displayNameFallback,
        bundleIdentifier: bundle.bundleIdentifier,
        version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ),
      environment: .init(
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: currentArchitectureName,
        isSandboxed: isSandboxed,
        isolation: isolation
      )
    )
  }

  private static var currentArchitectureName: String {
    #if arch(arm64)
    "Apple Silicon"
    #elseif arch(x86_64)
    "Intel"
    #else
    "Unknown"
    #endif
  }
}
