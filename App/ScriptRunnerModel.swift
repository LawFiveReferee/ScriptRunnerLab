import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ScriptRunnerModel {
  var descriptor: ScriptDescriptor?
  var result: ScriptExecutionResult?
  var status = ScriptExecutionStatus.ready
  var isRunning = false
  var favorites: [FavoriteScript]

  private static let favoritesKey = "favoriteScripts"

  init() {
    favorites = Self.loadFavorites()
  }

  var canRun: Bool {
    descriptor?.scriptType != .unsupported && !isRunning
  }

  var durationText: String {
    guard let result else { return "" }
    return result.executionDuration.formatted(.number.precision(.fractionLength(3))) + " s"
  }

  var defaultEditorName: String {
    guard let url = descriptor?.url,
          let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
      return "Default Editor"
    }
    return FileManager.default.displayName(atPath: applicationURL.path)
  }

  var selectedFavoriteID: UUID? {
    guard let selectedPath = descriptor?.url.standardizedFileURL.path(percentEncoded: false) else { return nil }
    return favorites.first {
      URL(fileURLWithPath: $0.lastKnownPath).standardizedFileURL.path(percentEncoded: false) == selectedPath
    }?.id
  }

  var isSelectedScriptFavorite: Bool {
    selectedFavoriteID != nil
  }

  func outputText(for mode: ResultDisplayMode) -> String {
    guard let result else { return "Results and errors will appear here." }
    if result.status == .completed {
      switch mode {
      case .aePrint:
        return result.rawResultDescription ?? "Script completed without a result."
      case .source:
        return result.sourceResultDescription ?? result.rawResultDescription ?? "Script completed without a result."
      }
    }

    var lines = [result.errorMessage ?? "Unknown AppleScript error"]
    if let errorNumber = result.errorNumber {
      lines.append("Error number: \(errorNumber)")
    }
    if let range = result.errorRange {
      lines.append("Source range: \(range.location)–\(range.location + range.length)")
    }
    return lines.joined(separator: "\n")
  }

  var diagnosticsText: String {
    var lines = [
      "Engine: OSAKit",
      "Sandbox: disabled",
      "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "Architecture: \(architectureName)"
    ]
    if let descriptor {
      lines.append("UTI: \(descriptor.typeIdentifier ?? "Unknown")")
      lines.append("Original URL preserved: yes")
    }
    if let result {
      lines.append("Request ID: \(result.requestID.uuidString)")
      lines.append("Started: \(result.startedAt.formatted(.iso8601))")
      lines.append("Completed: \(result.completedAt.formatted(.iso8601))")
      if let rawResultDescription = result.rawResultDescription {
        lines.append("Raw result: \(rawResultDescription)")
      }
    }
    return lines.joined(separator: "\n")
  }

  func receiveSelection(_ selection: Result<[URL], any Error>) {
    do {
      guard let url = try selection.get().first else { return }
      descriptor = ScriptDescriptor(url: url)
      result = nil
      status = .ready
    } catch {
      showLocalError(error.localizedDescription)
    }
  }

  func selectFavorite(id: UUID) {
    guard let index = favorites.firstIndex(where: { $0.id == id }) else { return }

    do {
      let resolution = try favorites[index].resolvedURL()
      let accessed = resolution.url.startAccessingSecurityScopedResource()
      defer {
        if accessed {
          resolution.url.stopAccessingSecurityScopedResource()
        }
      }

      let selectedDescriptor = ScriptDescriptor(url: resolution.url)
      descriptor = selectedDescriptor
      result = nil
      status = .ready

      let refreshed = try favorite(for: selectedDescriptor)
      favorites[index] = FavoriteScript(
        id: favorites[index].id,
        replacing: refreshed
      )
      favorites.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
      saveFavorites()
    } catch {
      showLocalError("This favorite could not be opened. Choose the script again to restore access. \(error.localizedDescription)")
    }
  }

  func setSelectedScriptFavorite(_ isFavorite: Bool) {
    if isFavorite {
      addSelectedScriptToFavorites()
    } else if let selectedFavoriteID {
      removeFavorite(id: selectedFavoriteID)
    }
  }

  func removeFavorite(id: UUID) {
    favorites.removeAll { $0.id == id }
    saveFavorites()
  }

  func run() {
    guard let descriptor, canRun else { return }
    isRunning = true
    status = .running

    let accessed = descriptor.url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        descriptor.url.stopAccessingSecurityScopedResource()
      }
    }

    result = OSAKitRunner().execute(url: descriptor.url)
    status = result?.status ?? .failed
    isRunning = false
  }

  func revealScript() {
    guard let url = descriptor?.url else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func openInDefaultEditor() {
    guard let url = descriptor?.url else { return }
    NSWorkspace.shared.open(url)
  }

  func copyResult(mode: ResultDisplayMode) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(outputText(for: mode), forType: .string)
  }

  func clearResult() {
    result = nil
    status = .ready
  }

  private var architectureName: String {
    #if arch(arm64)
    "Apple Silicon"
    #elseif arch(x86_64)
    "Intel"
    #else
    "Unknown"
    #endif
  }

  private func showLocalError(_ message: String) {
    let now = Date()
    result = ScriptExecutionResult(
      requestID: UUID(),
      status: .failed,
      sourceResultDescription: nil,
      rawResultDescription: nil,
      errorNumber: nil,
      errorMessage: message,
      errorBriefMessage: nil,
      errorRange: nil,
      executionDuration: 0,
      startedAt: now,
      completedAt: now
    )
    status = .failed
  }

  private func addSelectedScriptToFavorites() {
    guard let descriptor, !isSelectedScriptFavorite else { return }
    let accessed = descriptor.url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        descriptor.url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      favorites.append(try favorite(for: descriptor))
      favorites.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
      saveFavorites()
    } catch {
      showLocalError("This script could not be added to Favorites. \(error.localizedDescription)")
    }
  }

  private func favorite(for descriptor: ScriptDescriptor) throws -> FavoriteScript {
    try FavoriteScript(
      descriptor: descriptor,
      capabilities: ScriptCapability.detect(in: descriptor)
    )
  }

  private func saveFavorites() {
    guard let data = try? JSONEncoder().encode(favorites) else { return }
    UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: Self.favoritesKey)
  }

  private static func loadFavorites() -> [FavoriteScript] {
    guard let storedValue = UserDefaults.standard.string(forKey: favoritesKey),
          let data = storedValue.data(using: .utf8),
          let favorites = try? JSONDecoder().decode([FavoriteScript].self, from: data) else {
      return []
    }
    return favorites
  }
}
