import Foundation
import OSAKit

public struct ScriptCapability: Codable, Hashable, Identifiable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case applicationAutomation
    case framework
    case scriptLibrary
    case scriptingAdditions
    case bundledResources
    case pathToMe
    case userInterface
    case builtInProgress
  }

  public var kind: Kind
  public var detail: String?

  public var id: String {
    kind.rawValue + (detail.map { ":\($0)" } ?? "")
  }

  public var displayName: String {
    switch kind {
    case .applicationAutomation:
      "Application Automation"
    case .framework:
      detail.map { "Framework: \($0)" } ?? "Framework"
    case .scriptLibrary:
      detail.map { "Library: \($0)" } ?? "Script Library"
    case .scriptingAdditions:
      "Scripting Additions"
    case .bundledResources:
      "Bundled Resources"
    case .pathToMe:
      "Path to Me"
    case .userInterface:
      "User Interface"
    case .builtInProgress:
      "Built-in Progress"
    }
  }

  public init(kind: Kind, detail: String? = nil) {
    self.kind = kind
    self.detail = detail
  }

  public static func detect(in descriptor: ScriptDescriptor) -> [ScriptCapability] {
    let source = sourceText(for: descriptor)
    let lowercaseSource = source.lowercased()
    var capabilities = Set<ScriptCapability>()

    if lowercaseSource.contains("tell application") || lowercaseSource.contains("using terms from application") {
      capabilities.insert(ScriptCapability(kind: .applicationAutomation))
    }
    for framework in quotedNames(after: "framework", in: source) {
      capabilities.insert(ScriptCapability(kind: .framework, detail: framework))
    }
    for library in quotedNames(after: "script", in: source) {
      capabilities.insert(ScriptCapability(kind: .scriptLibrary, detail: library))
    }
    if lowercaseSource.contains("use scripting additions") {
      capabilities.insert(ScriptCapability(kind: .scriptingAdditions))
    }
    if lowercaseSource.contains("path to me") {
      capabilities.insert(ScriptCapability(kind: .pathToMe))
    }
    if lowercaseSource.contains("display dialog") || lowercaseSource.contains("display alert") {
      capabilities.insert(ScriptCapability(kind: .userInterface))
    }
    if lowercaseSource.contains("progress total steps")
      || lowercaseSource.contains("progress completed steps")
      || lowercaseSource.contains("progress description")
      || lowercaseSource.contains("progress additional description") {
      capabilities.insert(ScriptCapability(kind: .builtInProgress))
    }
    if hasBundledResources(descriptor: descriptor) || lowercaseSource.contains("path to resource") {
      capabilities.insert(ScriptCapability(kind: .bundledResources))
    }

    return capabilities.sorted {
      $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
    }
  }

  private static func sourceText(for descriptor: ScriptDescriptor) -> String {
    if descriptor.scriptType == .sourceAppleScript,
       let source = try? String(contentsOf: descriptor.url, encoding: .utf8) {
      return source
    }

    let scriptURL: URL
    if descriptor.scriptType == .appleScriptApplet {
      scriptURL = descriptor.url.appending(
        path: "Contents/Resources/Scripts/main.scpt",
        directoryHint: .notDirectory
      )
    } else {
      scriptURL = descriptor.url
    }

    var error: NSDictionary?
    return OSAScript(contentsOf: scriptURL, error: &error)?.source ?? ""
  }

  private static func quotedNames(after keyword: String, in source: String) -> [String] {
    let pattern = #"(?im)^\s*use\s+"# + keyword + #"\s+[\"“]([^\"”]+)[\"”]"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)

    return expression.matches(in: source, range: range).compactMap { match in
      guard match.numberOfRanges > 1,
            let nameRange = Range(match.range(at: 1), in: source) else {
        return nil
      }
      return String(source[nameRange])
    }
  }

  private static func hasBundledResources(descriptor: ScriptDescriptor) -> Bool {
    guard descriptor.isPackage else { return false }
    let resourcesURL = descriptor.url.appending(path: "Contents/Resources", directoryHint: .isDirectory)
    let contents = try? FileManager.default.contentsOfDirectory(
      at: resourcesURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    return contents?.isEmpty == false
  }
}
