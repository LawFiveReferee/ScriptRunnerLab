import Foundation

public struct ScriptExecutionLogEntry: Codable, Sendable {
  public var schemaVersion: Int
  public var host: Host
  public var script: Script
  public var environment: Environment
  public var engine: ScriptExecutionEngine
  public var result: ScriptExecutionResult

  public init(
    schemaVersion: Int = 1,
    host: Host,
    script: Script,
    environment: Environment,
    engine: ScriptExecutionEngine,
    result: ScriptExecutionResult
  ) {
    self.schemaVersion = schemaVersion
    self.host = host
    self.script = script
    self.environment = environment
    self.engine = engine
    self.result = result
  }

  public struct Host: Codable, Sendable {
    public var name: String
    public var bundleIdentifier: String?
    public var version: String?
    public var build: String?

    public init(name: String, bundleIdentifier: String?, version: String?, build: String?) {
      self.name = name
      self.bundleIdentifier = bundleIdentifier
      self.version = version
      self.build = build
    }
  }

  public struct Script: Codable, Sendable {
    public var name: String
    public var path: String
    public var fileExtension: String
    public var typeIdentifier: String?
    public var scriptType: ScriptType
    public var isPackage: Bool

    public init(
      name: String,
      path: String,
      fileExtension: String,
      typeIdentifier: String?,
      scriptType: ScriptType,
      isPackage: Bool
    ) {
      self.name = name
      self.path = path
      self.fileExtension = fileExtension
      self.typeIdentifier = typeIdentifier
      self.scriptType = scriptType
      self.isPackage = isPackage
    }
  }

  public struct Environment: Codable, Sendable {
    public var operatingSystem: String
    public var architecture: String
    public var isSandboxed: Bool
    public var isolation: String

    public init(operatingSystem: String, architecture: String, isSandboxed: Bool, isolation: String) {
      self.operatingSystem = operatingSystem
      self.architecture = architecture
      self.isSandboxed = isSandboxed
      self.isolation = isolation
    }
  }
}

public enum ScriptExecutionEngine: String, Codable, Sendable {
  case osaKit
  case nsWorkspaceApplet
}
