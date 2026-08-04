import Foundation

public struct ScriptDescriptor: Sendable {
  public var url: URL
  public var displayName: String
  public var fileExtension: String
  public var typeIdentifier: String?
  public var scriptType: ScriptType
  public var isPackage: Bool
  public var isCompiled: Bool

  public init(url: URL) {
    let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey, .isPackageKey])
    let fileExtension = url.pathExtension.lowercased()

    self.url = url
    self.displayName = url.lastPathComponent
    self.fileExtension = fileExtension
    self.typeIdentifier = resourceValues?.contentType?.identifier
    self.scriptType = ScriptType(fileExtension: fileExtension, isPackage: resourceValues?.isPackage == true)
    self.isPackage = resourceValues?.isPackage == true
    self.isCompiled = fileExtension == "scpt" || fileExtension == "scptd"
  }
}

public enum ScriptType: String, Codable, Hashable, Sendable {
  case sourceAppleScript
  case compiledAppleScript
  case scriptBundle
  case unsupported

  public init(fileExtension: String, isPackage: Bool) {
    switch fileExtension {
    case "applescript":
      self = .sourceAppleScript
    case "scpt":
      self = .compiledAppleScript
    case "scptd" where isPackage:
      self = .scriptBundle
    default:
      self = .unsupported
    }
  }

  public var displayName: String {
    switch self {
    case .sourceAppleScript: "AppleScript source"
    case .compiledAppleScript: "Compiled AppleScript"
    case .scriptBundle: "AppleScript bundle"
    case .unsupported: "Unsupported"
    }
  }
}
