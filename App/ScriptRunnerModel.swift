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
  static let shared = ScriptRunnerModel()

  var descriptor: ScriptDescriptor?
  var result: ScriptExecutionResult?
  var status = ScriptExecutionStatus.ready
  var isRunning = false
  var favorites: [FavoriteScript]
  var scriptsFolderURL: URL?
  var scriptsFolderEntries: [ScriptFolderEntry] = []
  var executedScriptPaths: Set<String> = []
  var executionLogURL: URL
  var scriptProgress: ScriptProgressSnapshot?
  var compatibilityResults: [String: CompatibilityTestResult] = [:]
  var isRunningCompatibilitySuite = false
  var currentCompatibilityTestName: String?
  var compatibilitySuiteStartedAt: Date?
  var compatibilitySuiteCompletedAt: Date?
  var scriptedInteractivePrompt: ScriptedInteractivePrompt?
  var scriptCollectionReport: ScriptCollectionExecutionReport?

  private static let favoritesKey = "favoriteScripts"
  private static let scriptsFolderBookmarkKey = "scriptsFolderBookmark"
  private let runnerService: ScriptRunnerService
  private var executionTask: Task<Void, Never>?
  private var scriptsFolderAccessURL: URL?
  private var scriptsFolderMonitors: [DispatchSourceFileSystemObject] = []
  private var scriptedAutomaticCompletion: ((String) -> Void)?
  private var isRunningScriptCollection = false
  @ObservationIgnored private var scriptedInteractiveContinuation:
    CheckedContinuation<ScriptCollectionInteractiveAction, Never>?

  init() {
    let executionLogURL = Self.defaultExecutionLogURL
    self.runnerService = ScriptRunnerService(
      configuration: .current(
        helperExecutableURL: Self.helperExecutableURL,
        workingDirectoryName: "ScriptRunnerLab",
        logURL: executionLogURL,
        displayNameFallback: "ScriptRunnerLab"
      )
    )
    self.executionLogURL = executionLogURL
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

  var compatibilityTests: [CompatibilityTestDefinition] {
    CompatibilityTestDefinition.all
  }

  var automaticCompatibilityTests: [CompatibilityTestDefinition] {
    CompatibilityTestDefinition.automaticTests
  }

  var deferredCompatibilityTests: [CompatibilityTestDefinition] {
    CompatibilityTestDefinition.deferredTests
  }

  var completedCompatibilityTestCount: Int {
    compatibilityResults.values.filter { [.passed, .failed, .stopped].contains($0.state) }.count
  }

  var passedCompatibilityTestCount: Int {
    compatibilityResults.values.filter { $0.state == .passed }.count
  }

  var failedCompatibilityTestCount: Int {
    compatibilityResults.values.filter { $0.state == .failed }.count
  }

  var hasCompatibilityResults: Bool {
    completedCompatibilityTestCount > 0
  }

  var compatibilityContentAssertionCount: Int {
    automaticCompatibilityTests.reduce(0) { $0 + ($1.expectedOutcome?.assertions.count ?? 0) }
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
      "Architecture: \(Self.currentArchitectureName)"
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

  func hasExecuted(_ test: CompatibilityTestDefinition) -> Bool {
    guard let url = compatibilityTestURL(for: test) else { return false }
    return executedScriptPaths.contains(Self.scriptIdentity(for: url))
  }

  func runCompatibilityTest(
    _ test: CompatibilityTestDefinition,
    timeout: TimeInterval
  ) {
    guard test.disposition != .automatic, !isRunning else { return }
    guard let url = compatibilityTestURL(for: test),
          FileManager.default.fileExists(atPath: url.path) else {
      showLocalError("The bundled compatibility test could not be found.")
      return
    }
    selectScript(at: url)
    run(timeout: timeout)
  }

  @discardableResult
  func executeScripts(
    in directoryURL: URL,
    mode: ScriptCollectionExecutionMode,
    completion: ((String) -> Void)? = nil
  ) -> Bool {
    guard !isRunning, !isRunningScriptCollection else {
      showLocalError("A script execution is already in progress.")
      return false
    }
    let entries = Self.scriptEntries(in: directoryURL).filter { $0.descriptor.scriptType != .unsupported }
    guard !entries.isEmpty else {
      showLocalError("No supported scripts were found in the specified directory.")
      return false
    }
    scriptedInteractivePrompt = nil
    scriptCollectionReport = nil
    scriptedAutomaticCompletion = completion
    isRunningScriptCollection = true
    switch mode {
    case .automatically:
      runScriptedDirectoryAutomatically(directoryURL: directoryURL)
    case .interactively:
      runScriptedDirectoryInteractively(directoryURL: directoryURL)
    }
    return true
  }

  func repeatScriptedInteractiveScript() {
    resolveScriptedInteractivePrompt(with: .runAgain)
  }

  func advanceScriptedInteractiveRun() {
    resolveScriptedInteractivePrompt(with: .runNext)
  }

  func quitScriptedInteractiveRun() {
    resolveScriptedInteractivePrompt(with: .quit)
  }

  func refreshScriptsFolder() {
    guard let scriptsFolderURL else { return }
    scriptsFolderEntries = Self.scriptEntries(in: scriptsFolderURL)
  }

  func revealScriptsFolder() {
    guard let scriptsFolderURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([scriptsFolderURL])
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
    isRunning = true
    status = .running
    result = nil
    scriptProgress = nil

    executionTask = Task { [weak self] in
      guard let self else { return }
      let executionResult = await runnerService.execute(
        scriptURL: descriptor.url,
        timeout: timeout
      ) { [weak self] snapshot in
        self?.scriptProgress = snapshot
      }
      result = executionResult
      status = executionResult.status
      isRunning = false
      scriptProgress = nil
      executionTask = nil
    }
  }

  func runAutomaticCompatibilitySuite() {
    guard !isRunning, let compatibilityTestsURL = Self.bundledCompatibilityTestsURL else {
      if Self.bundledCompatibilityTestsURL == nil {
        showLocalError("The bundled CompatibilityTests folder could not be found.")
      }
      return
    }

    compatibilityResults = Dictionary(
      uniqueKeysWithValues: automaticCompatibilityTests.map { ($0.id, .pending) }
    )
    isRunning = true
    isRunningCompatibilitySuite = true
    currentCompatibilityTestName = nil
    status = .running
    result = nil
    scriptProgress = nil
    compatibilitySuiteStartedAt = Date()
    compatibilitySuiteCompletedAt = nil

    executionTask = Task { [weak self] in
      guard let self else { return }
      let report = await runnerService.executeCompatibilitySuite(
        testsRootURL: compatibilityTestsURL,
        tests: automaticCompatibilityTests,
        testStarted: compatibilityTestStarted,
        progressHandler: compatibilityProgressReceived,
        testCompleted: compatibilityTestCompleted
      )

      currentCompatibilityTestName = nil
      scriptProgress = nil
      isRunningCompatibilitySuite = false
      isRunning = false
      compatibilitySuiteStartedAt = report.startedAt
      compatibilitySuiteCompletedAt = report.completedAt
      if report.completion == .stopped {
        status = .cancelled
      } else if report.failedCount > 0 {
        status = .failed
      } else {
        status = .completed
      }
      executionTask = nil
    }
  }

  func cancel() {
    guard isRunning else { return }
    if isRunningScriptCollection {
      runnerService.cancel()
    } else {
      executionTask?.cancel()
      runnerService.cancel()
    }
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

  func copyCompatibilitySummary() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(compatibilitySummaryText, forType: .string)
  }

  func copyCompatibilitySummaryJSON() {
    guard let data = try? compatibilitySummary.jsonData(),
          let string = String(data: data, encoding: .utf8) else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
  }

  func clearResult() {
    result = nil
    status = .ready
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

  private var executionEngineName: String {
    descriptor?.scriptType == .appleScriptApplet ? "NSWorkspace applet launch" : "OSAKit"
  }

  private var compatibilitySummaryText: String {
    compatibilitySummary.text
  }

  private var compatibilitySummary: CompatibilitySuiteSummary {
    CompatibilitySuiteSummary(
      suiteName: "ScriptRunnerLab Compatibility Suite",
      startedAt: compatibilitySuiteStartedAt,
      completedAt: compatibilitySuiteCompletedAt,
      configuration: runnerService.configuration,
      automaticTests: automaticCompatibilityTests,
      results: compatibilityResults,
      deferredTests: deferredCompatibilityTests
    )
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

  private func compatibilityTestStarted(_ test: CompatibilityTestDefinition) {
    currentCompatibilityTestName = test.displayName
    compatibilityResults[test.id] = .running
    guard let rootURL = Self.bundledCompatibilityTestsURL else { return }
    executedScriptPaths.insert(Self.scriptIdentity(for: rootURL.appending(path: test.relativePath)))
  }

  private func compatibilityProgressReceived(
    _ test: CompatibilityTestDefinition,
    _ snapshot: ScriptProgressSnapshot
  ) {
    scriptProgress = snapshot
  }

  private func compatibilityTestCompleted(
    _ test: CompatibilityTestDefinition,
    _ testResult: CompatibilityTestResult
  ) {
    compatibilityResults[test.id] = testResult
    scriptProgress = nil
  }

  private func runScriptedDirectoryAutomatically(directoryURL: URL) {
    let timeout = scriptedExecutionTimeout
    isRunning = true
    status = .running
    result = nil
    executionTask = Task { [weak self] in
      guard let self else { return }
      await performScriptedDirectoryAutomatically(directoryURL: directoryURL, timeout: timeout)
    }
  }

  private func performScriptedDirectoryAutomatically(
    directoryURL: URL,
    timeout: TimeInterval
  ) async {
    let report: ScriptCollectionExecutionReport
    do {
      report = try await runnerService.executeAutomatically(
        directoryURL: directoryURL,
        timeout: timeout,
        itemStarted: collectionItemStarted,
        progressHandler: collectionProgressReceived
      )
    } catch {
      showLocalError(error.localizedDescription)
      scriptedAutomaticCompletion?(error.localizedDescription)
      scriptedAutomaticCompletion = nil
      isRunningScriptCollection = false
      executionTask = nil
      return
    }
    isRunning = false
    status = report.entries.last?.result.status == .cancelled
      ? .cancelled
      : (report.succeeded ? .completed : .failed)
    scriptCollectionReport = report
    result = ScriptExecutionResult(
      requestID: UUID(),
      status: .completed,
      sourceResultDescription: report.text,
      rawResultDescription: report.text,
      errorNumber: nil,
      errorMessage: nil,
      errorBriefMessage: nil,
      errorRange: nil,
      executionDuration: report.completedAt.timeIntervalSince(report.startedAt),
      startedAt: report.startedAt,
      completedAt: report.completedAt
    )
    scriptedAutomaticCompletion?(report.text)
    scriptedAutomaticCompletion = nil
    isRunningScriptCollection = false
    executionTask = nil
  }

  private func collectionItemStarted(_ item: ScriptCollectionItem) {
    descriptor = item.descriptor
    executedScriptPaths.insert(Self.scriptIdentity(for: item.url))
  }

  private func collectionProgressReceived(
    _ item: ScriptCollectionItem,
    _ snapshot: ScriptProgressSnapshot
  ) {
    scriptProgress = snapshot
  }

  private func runScriptedDirectoryInteractively(directoryURL: URL) {
    let timeout = scriptedExecutionTimeout
    isRunning = true
    status = .running
    result = nil
    executionTask = Task { [weak self] in
      guard let self else { return }
      do {
        let outcome = try await runnerService.executeInteractively(
          directoryURL: directoryURL,
          timeout: timeout,
          itemStarted: collectionItemStarted,
          progressHandler: collectionProgressReceived,
          itemCompleted: interactiveCollectionItemCompleted,
          actionProvider: scriptedInteractiveAction
        )
        scriptCollectionReport = outcome.report
        status = outcome.completion == .quit
          ? .cancelled
          : (outcome.report.succeeded ? .completed : .failed)
      } catch {
        showLocalError(error.localizedDescription)
      }
      isRunning = false
      isRunningScriptCollection = false
      executionTask = nil
    }
  }

  private func interactiveCollectionItemCompleted(
    _ item: ScriptCollectionItem,
    _ executionResult: ScriptExecutionResult
  ) async {
    result = executionResult
    status = executionResult.status
    isRunning = false
  }

  private func scriptedInteractiveAction(
    _ step: ScriptCollectionInteractiveStep
  ) async -> ScriptCollectionInteractiveAction {
    scriptedInteractivePrompt = ScriptedInteractivePrompt(
      scriptName: step.item.descriptor.displayName,
      resultText: outputText(for: .source),
      nextScriptName: step.nextItem?.descriptor.displayName
    )
    return await withCheckedContinuation { continuation in
      scriptedInteractiveContinuation = continuation
    }
  }

  private func resolveScriptedInteractivePrompt(with action: ScriptCollectionInteractiveAction) {
    scriptedInteractivePrompt = nil
    let continuation = scriptedInteractiveContinuation
    scriptedInteractiveContinuation = nil
    continuation?.resume(returning: action)
    if action != .quit {
      isRunning = true
      status = .running
      result = nil
    }
  }

  private var scriptedExecutionTimeout: TimeInterval {
    let storedValue = UserDefaults.standard.integer(forKey: "executionTimeout")
    return TimeInterval(storedValue > 0 ? storedValue : ExecutionTimeout.thirtySeconds.rawValue)
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

  private func compatibilityTestURL(for test: CompatibilityTestDefinition) -> URL? {
    Self.bundledCompatibilityTestsURL?.appending(path: test.relativePath)
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
    CompatibilityTestResources.rootURL
  }

  private static var helperExecutableURL: URL {
    Bundle.main.bundleURL.appending(
      path: "Contents/Helpers/ScriptRunnerHelper.app/Contents/MacOS/ScriptRunnerHelper"
    )
  }

  private static func scriptEntries(in folderURL: URL) -> [ScriptFolderEntry] {
    ScriptCollectionDiscovery().scripts(in: folderURL).map { item in
      ScriptFolderEntry(
        url: item.url,
        relativePath: item.relativePath,
        descriptor: item.descriptor
      )
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
    try FavoriteScript(descriptor: descriptor)
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
