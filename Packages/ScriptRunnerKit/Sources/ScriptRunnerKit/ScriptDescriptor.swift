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
    let isPackage = resourceValues?.isPackage == true
    let appletScriptURL = url.appending(path: "Contents/Resources/Scripts/main.scpt", directoryHint: .notDirectory)
    let isAppleScriptApplet = fileExtension == "app"
      && isPackage
      && FileManager.default.fileExists(atPath: appletScriptURL.path)

    self.url = url
    self.displayName = url.lastPathComponent
    self.fileExtension = fileExtension
    self.typeIdentifier = resourceValues?.contentType?.identifier
    self.scriptType = ScriptType(
      fileExtension: fileExtension,
      isPackage: isPackage,
      isAppleScriptApplet: isAppleScriptApplet
    )
    self.isPackage = isPackage
    self.isCompiled = fileExtension == "scpt" || fileExtension == "scptd" || isAppleScriptApplet
  }
}

public enum ScriptType: String, Codable, Hashable, Sendable {
  case sourceAppleScript
  case compiledAppleScript
  case scriptBundle
  case appleScriptApplet
  case unsupported

  public init(fileExtension: String, isPackage: Bool, isAppleScriptApplet: Bool = false) {
    switch fileExtension {
    case "applescript":
      self = .sourceAppleScript
    case "scpt":
      self = .compiledAppleScript
    case "scptd" where isPackage:
      self = .scriptBundle
    case "app" where isAppleScriptApplet:
      self = .appleScriptApplet
    default:
      self = .unsupported
    }
  }

  public var displayName: String {
    switch self {
    case .sourceAppleScript: "AppleScript source"
    case .compiledAppleScript: "Compiled AppleScript"
    case .scriptBundle: "AppleScript bundle"
    case .appleScriptApplet: "AppleScript applet"
    case .unsupported: "Unsupported"
    }
  }
}
