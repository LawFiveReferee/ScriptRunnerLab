import AppKit
import CoreServices
import Darwin
import Dispatch
import Foundation
import Observation
import ScriptRunnerKit

@MainActor
@Observable
final class ScriptRunnerModel {
  var descriptor: ScriptDescriptor?
  var result: ScriptExecutionResult?
  var status = ScriptExecutionStatus.ready
  var isRunning = false
  var favorites: [FavoriteScript]
  var scriptsFolderURL: URL?
  var scriptsFolderEntries: [ScriptFolderEntry] = []
  var executedScriptPaths: Set<String> = []
  var executionLogURL: URL

  private static let favoritesKey = "favoriteScripts"
  private static let scriptsFolderBookmarkKey = "scriptsFolderBookmark"
  private let helperRunner = HelperProcessRunner()
  private let executionLogWriter: ScriptExecutionLogWriter
  private var executionTask: Task<Void, Never>?
  private var scriptsFolderAccessURL: URL?
  private var scriptsFolderMonitors: [DispatchSourceFileSystemObject] = []

  init() {
    let executionLogURL = Self.defaultExecutionLogURL
    self.executionLogURL = executionLogURL
    self.executionLogWriter = ScriptExecutionLogWriter(fileURL: executionLogURL)
    favorites = Self.loadFavorites()
    scriptsFolderURL = nil
    restoreScriptsFolder()
  }

  var canRun: Bool {
    descriptor?.scriptType != .unsupported && !isRunning
  }

  var durationText: String {
    guard let result else { return "" }
    return result.executionDuration.formatted(.number.precision(.fractionLength(3))) + " s"
  }

  var defaultEditorName: String {
    guard let applicationURL = defaultEditorURL else {
      return "Default Editor"
    }
    return FileManager.default.displayName(atPath: applicationURL.path)
  }

  var scriptsFolderDisplayName: String {
    guard let scriptsFolderURL else { return "Scripts Folder" }
    return FileManager.default.displayName(atPath: scriptsFolderURL.path)
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

    var lines: [String] = []
    if result.status == .compileError {
      lines.append(result.status.displayName)
    }
    lines.append(result.errorMessage ?? result.errorBriefMessage ?? "Unknown AppleScript error")
    if let errorNumber = result.errorNumber {
      lines.append("Error number: \(errorNumber)")
    }
    if let range = result.errorRange {
      lines.append("Source range: \(range.location)–\(range.location + range.length)")
    }
    return lines.joined(separator: "\n")
  }

  var diagnosticsText: String {
    var lines: [String] = []
    if let descriptor {
      lines.append("Script: \(descriptor.displayName)")
      lines.append("Path: \(descriptor.url.path(percentEncoded: false))")
    }
    lines.append(contentsOf: [
      "Engine: \(executionEngineName)",
      "Isolation: ScriptRunnerHelper (one process per request)",
      "Sandbox: disabled",
      "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "Architecture: \(architectureName)"
    ])
    if let descriptor {
      lines.append("Script type: \(descriptor.scriptType.displayName)")
      lines.append("UTI: \(descriptor.typeIdentifier ?? "Unknown")")
      lines.append("Original URL preserved: yes")
    }
    lines.append("Execution log: \(executionLogURL.path(percentEncoded: false))")
    if let result {
      lines.append("Request ID: \(result.requestID.uuidString)")
      lines.append("Started: \(result.startedAt.formatted(.iso8601))")
      lines.append("Completed: \(result.completedAt.formatted(.iso8601))")
      lines.append("Duration: \(result.executionDuration.formatted(.number.precision(.fractionLength(3)))) s")
      lines.append("Status: \(result.status.displayName)")
      if let errorNumber = result.errorNumber {
        lines.append("Error number: \(errorNumber)")
      }
      if let errorRange = result.errorRange {
        lines.append("Source range: \(errorRange.location)–\(errorRange.location + errorRange.length)")
      }
      if result.status == .completed,
         let returnValue = result.sourceResultDescription ?? result.rawResultDescription {
        lines.append("Return value: \(returnValue)")
      } else if let errorMessage = result.errorMessage ?? result.errorBriefMessage {
        lines.append("Error: \(errorMessage)")
      }
    }
    return lines.joined(separator: "\n")
  }

  func receiveSelection(_ selection: Result<[URL], any Error>) {
    do {
      guard let url = try selection.get().first else { return }
      selectScript(at: url)
    } catch {
      showLocalError(error.localizedDescription)
    }
  }

  func receiveFolderSelection(_ selection: Result<[URL], any Error>) {
    do {
      guard let url = try selection.get().first else { return }
      try setScriptsFolder(url, persist: true)
    } catch {
      showLocalError("The scripts folder could not be opened. \(error.localizedDescription)")
    }
  }

  func receiveDroppedURLs(_ urls: [URL]) -> Bool {
    guard let url = urls.first(where: Self.isScriptURL) else { return false }
    selectScript(at: url)
    return true
  }

  func selectFolderScript(_ entry: ScriptFolderEntry) {
    selectScript(at: entry.url)
  }

  func hasExecuted(_ entry: ScriptFolderEntry) -> Bool {
    executedScriptPaths.contains(Self.scriptIdentity(for: entry.url))
  }

  func refreshScriptsFolder() {
    guard let scriptsFolderURL else { return }
    scriptsFolderEntries = Self.scriptEntries(in: scriptsFolderURL)
  }

  func useBundledCompatibilityTests() {
    guard let url = Self.bundledCompatibilityTestsURL else {
      showLocalError("The bundled CompatibilityTests folder could not be found.")
      return
    }

    do {
      try setScriptsFolder(url, persist: false)
      UserDefaults.standard.removeObject(forKey: Self.scriptsFolderBookmarkKey)
    } catch {
      showLocalError("The bundled CompatibilityTests folder could not be opened. \(error.localizedDescription)")
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

  func run(timeout: TimeInterval) {
    guard let descriptor, canRun else { return }
    executedScriptPaths.insert(Self.scriptIdentity(for: descriptor.url))
    let accessed = descriptor.url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        descriptor.url.stopAccessingSecurityScopedResource()
      }
    }

    let request: ScriptExecutionRequest
    do {
      request = try ScriptExecutionRequest(scriptURL: descriptor.url)
    } catch {
      showLocalError("The script could not be prepared for the helper. \(error.localizedDescription)")
      if let result {
        Task { await recordExecution(descriptor: descriptor, result: result) }
      }
      return
    }

    isRunning = true
    status = .running
    result = nil
    let startedAt = Date()

    executionTask = Task { [weak self] in
      guard let self else { return }
      do {
        let executionResult = try await helperRunner.execute(request: request, timeout: timeout)
        result = executionResult
        status = executionResult.status
        isRunning = false
      } catch let error as HelperProcessError {
        let failureStatus: ScriptExecutionStatus
        switch error {
        case .cancelled:
          failureStatus = .cancelled
        case .timedOut:
          failureStatus = .timedOut
        default:
          failureStatus = .failed
        }
        showLocalError(
          error.localizedDescription,
          status: failureStatus,
          requestID: request.requestID,
          startedAt: startedAt
        )
      } catch {
        showLocalError(
          error.localizedDescription,
          requestID: request.requestID,
          startedAt: startedAt
        )
      }
      if let result {
        await recordExecution(descriptor: descriptor, result: result)
      }
      executionTask = nil
    }
  }

  func cancel() {
    guard isRunning else { return }
    executionTask?.cancel()
    helperRunner.cancel()
  }

  func revealScript() {
    guard let url = descriptor?.url else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func openInDefaultEditor() {
    guard let url = descriptor?.url, let editorURL = defaultEditorURL else { return }
    NSWorkspace.shared.open(
      [url],
      withApplicationAt: editorURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { [weak self] _, error in
      guard let error else { return }
      Task { @MainActor in
        self?.showLocalError("The script could not be opened in the default editor. \(error.localizedDescription)")
      }
    }
  }

  func copyResult(mode: ResultDisplayMode) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(outputText(for: mode), forType: .string)
  }

  func copyDiagnostics() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(diagnosticsText, forType: .string)
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

  private var executionEngineName: String {
    descriptor?.scriptType == .appleScriptApplet ? "NSWorkspace applet launch" : "OSAKit"
  }

  private var defaultEditorURL: URL? {
    guard descriptor != nil else { return nil }
    let contentType = editorContentType as CFString
    guard let unmanagedIdentifier = LSCopyDefaultRoleHandlerForContentType(contentType, .editor) else {
      return nil
    }
    let bundleIdentifier = unmanagedIdentifier.takeRetainedValue() as String
    return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
  }

  private var editorContentType: String {
    switch descriptor?.url.pathExtension.lowercased() {
    case "scpt":
      "com.apple.applescript.script"
    case "scptd":
      "com.apple.applescript.script-bundle"
    default:
      "com.apple.applescript.text"
    }
  }

  private func showLocalError(
    _ message: String,
    status: ScriptExecutionStatus = .failed,
    requestID: UUID = UUID(),
    startedAt: Date = Date()
  ) {
    result = .failure(
      requestID: requestID,
      status: status,
      message: message,
      startedAt: startedAt
    )
    self.status = status
    isRunning = false
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

  private func selectScript(at url: URL) {
    descriptor = ScriptDescriptor(url: url)
    result = nil
    status = .ready
  }

  private func restoreScriptsFolder() {
    if let bookmark = UserDefaults.standard.data(forKey: Self.scriptsFolderBookmarkKey) {
      do {
        var isStale = false
        let url = try URL(
          resolvingBookmarkData: bookmark,
          options: [.withSecurityScope],
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )
        try setScriptsFolder(url, persist: isStale)
        return
      } catch {
        UserDefaults.standard.removeObject(forKey: Self.scriptsFolderBookmarkKey)
      }
    }

    if let url = Self.bundledCompatibilityTestsURL {
      try? setScriptsFolder(url, persist: false)
    }
  }

  private func setScriptsFolder(_ url: URL, persist: Bool) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw CocoaError(.fileNoSuchFile)
    }

    if scriptsFolderAccessURL != url {
      scriptsFolderAccessURL?.stopAccessingSecurityScopedResource()
      if url.startAccessingSecurityScopedResource() {
        scriptsFolderAccessURL = url
      } else {
        scriptsFolderAccessURL = nil
      }
    }

    scriptsFolderURL = url
    refreshScriptsFolder()
    startScriptsFolderMonitoring(at: url)

    if persist {
      let bookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      UserDefaults.standard.set(bookmark, forKey: Self.scriptsFolderBookmarkKey)
    }
  }

  private static var bundledCompatibilityTestsURL: URL? {
    Bundle.main.url(forResource: "CompatibilityTests", withExtension: nil)
  }

  private static func scriptEntries(in folderURL: URL) -> [ScriptFolderEntry] {
    let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
    guard let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var entries: [ScriptFolderEntry] = []
    while let url = enumerator.nextObject() as? URL {
      let fileExtension = url.pathExtension.lowercased()
      if fileExtension == "scptd" || fileExtension == "app" {
        enumerator.skipDescendants()
      }
      guard isScriptURL(url) else { continue }

      let folderComponents = folderURL.standardizedFileURL.pathComponents
      let scriptComponents = url.standardizedFileURL.pathComponents
      let relativePath = scriptComponents.dropFirst(folderComponents.count).joined(separator: "/")
      entries.append(
        ScriptFolderEntry(
          url: url,
          relativePath: relativePath,
          descriptor: ScriptDescriptor(url: url)
        )
      )
    }

    return entries.sorted {
      $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
    }
  }

  private static func isScriptURL(_ url: URL) -> Bool {
    ["applescript", "scpt", "scptd", "app"].contains(url.pathExtension.lowercased())
  }

  private func startScriptsFolderMonitoring(at folderURL: URL) {
    scriptsFolderMonitors.forEach { $0.cancel() }
    scriptsFolderMonitors.removeAll()

    for directoryURL in Self.directoriesToMonitor(in: folderURL) {
      let descriptor = open(directoryURL.path, O_EVTONLY)
      guard descriptor >= 0 else { continue }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor,
        eventMask: [.write, .extend, .attrib, .link, .rename, .delete, .revoke],
        queue: .main
      )
      source.setEventHandler { [weak self] in
        Task { @MainActor [weak self] in
          guard let self, self.scriptsFolderURL?.standardizedFileURL == folderURL.standardizedFileURL else {
            return
          }
          self.refreshScriptsFolder()
          self.startScriptsFolderMonitoring(at: folderURL)
        }
      }
      source.setCancelHandler {
        close(descriptor)
      }
      source.resume()
      scriptsFolderMonitors.append(source)
    }
  }

  private static func directoriesToMonitor(in folderURL: URL) -> [URL] {
    let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
    guard let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles]
    ) else {
      return [folderURL]
    }

    var directories = [folderURL]
    while let url = enumerator.nextObject() as? URL {
      let fileExtension = url.pathExtension.lowercased()
      if fileExtension == "scptd" || fileExtension == "app" {
        enumerator.skipDescendants()
        continue
      }
      if (try? url.resourceValues(forKeys: Set(resourceKeys)).isDirectory) == true {
        directories.append(url)
      }
    }
    return directories
  }

  private static func scriptIdentity(for url: URL) -> String {
    url.standardizedFileURL.path(percentEncoded: false)
  }

  private func recordExecution(descriptor: ScriptDescriptor, result: ScriptExecutionResult) async {
    let bundle = Bundle.main
    let entry = ScriptExecutionLogEntry(
      host: .init(
        name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "ScriptRunnerLab",
        bundleIdentifier: bundle.bundleIdentifier,
        version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ),
      script: .init(
        name: descriptor.displayName,
        path: descriptor.url.path(percentEncoded: false),
        fileExtension: descriptor.fileExtension,
        typeIdentifier: descriptor.typeIdentifier,
        scriptType: descriptor.scriptType,
        isPackage: descriptor.isPackage
      ),
      environment: .init(
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: architectureName,
        isSandboxed: false,
        isolation: "ScriptRunnerHelper (one process per request)"
      ),
      engine: descriptor.scriptType == .appleScriptApplet ? .nsWorkspaceApplet : .osaKit,
      result: result
    )
    try? await executionLogWriter.append(entry)
  }

  private static var defaultExecutionLogURL: URL {
    let applicationSupportURL = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory
    return applicationSupportURL
      .appending(path: "ScriptRunnerLab", directoryHint: .isDirectory)
      .appending(path: "ScriptExecutionLog.jsonl", directoryHint: .notDirectory)
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
