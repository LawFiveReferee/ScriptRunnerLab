import Foundation

struct ScriptDescriptor: Sendable {
  var url: URL
  var displayName: String
  var fileExtension: String
  var typeIdentifier: String?
  var scriptType: ScriptType
  var isPackage: Bool
  var isCompiled: Bool

  init(url: URL) {
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

enum ScriptType: String, Sendable {
  case sourceAppleScript
  case compiledAppleScript
  case scriptBundle
  case unsupported

  init(fileExtension: String, isPackage: Bool) {
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

  var displayName: String {
    switch self {
    case .sourceAppleScript: "AppleScript source"
    case .compiledAppleScript: "Compiled AppleScript"
    case .scriptBundle: "AppleScript bundle"
    case .unsupported: "Unsupported"
    }
  }
}
