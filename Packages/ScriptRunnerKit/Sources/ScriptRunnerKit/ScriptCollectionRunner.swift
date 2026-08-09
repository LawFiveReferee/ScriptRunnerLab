import Foundation

public struct ScriptCollectionItem: Identifiable, Sendable {
  public var url: URL
  public var relativePath: String
  public var descriptor: ScriptDescriptor

  public var id: String {
    url.standardizedFileURL.path(percentEncoded: false)
  }

  public init(url: URL, relativePath: String, descriptor: ScriptDescriptor) {
    self.url = url
    self.relativePath = relativePath
    self.descriptor = descriptor
  }
}

public struct ScriptCollectionDiscovery: Sendable {
  public init() {}

  public func scripts(in directoryURL: URL) -> [ScriptCollectionItem] {
    let keys: [URLResourceKey] = [.isPackageKey]
    guard let enumerator = FileManager.default.enumerator(
      at: directoryURL,
      includingPropertiesForKeys: keys,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var items: [ScriptCollectionItem] = []
    while let url = enumerator.nextObject() as? URL {
      let fileExtension = url.pathExtension.lowercased()
      if fileExtension == "scptd" || fileExtension == "app" {
        enumerator.skipDescendants()
      }
      let descriptor = ScriptDescriptor(url: url)
      guard descriptor.scriptType != .unsupported else { continue }
      let relativePath = url.standardizedFileURL.pathComponents
        .dropFirst(directoryURL.standardizedFileURL.pathComponents.count)
        .joined(separator: "/")
      items.append(ScriptCollectionItem(url: url, relativePath: relativePath, descriptor: descriptor))
    }
    return items.sorted {
      $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
    }
  }
}

@MainActor
public final class ScriptCollectionRunner {
  private var discovery: ScriptCollectionDiscovery
  private var requestExecutor: (
    ScriptExecutionRequest,
    TimeInterval,
    @escaping (ScriptProgressSnapshot) -> Void
  ) async throws -> ScriptExecutionResult
  private var cancellationHandler: () -> Void
  private var currentExecutionTask: Task<ScriptExecutionResult, Never>?

  public init(
    helperRunner: ScriptHelperProcessRunner,
    discovery: ScriptCollectionDiscovery = ScriptCollectionDiscovery()
  ) {
    self.discovery = discovery
    self.requestExecutor = { request, timeout, progressHandler in
      try await helperRunner.execute(
        request: request,
        timeout: timeout,
        progressHandler: progressHandler
      )
    }
    self.cancellationHandler = helperRunner.cancel
  }

  init(
    discovery: ScriptCollectionDiscovery = ScriptCollectionDiscovery(),
    requestExecutor: @escaping (
      ScriptExecutionRequest,
      TimeInterval,
      @escaping (ScriptProgressSnapshot) -> Void
    ) async throws -> ScriptExecutionResult,
    cancellationHandler: @escaping () -> Void = {}
  ) {
    self.discovery = discovery
    self.requestExecutor = requestExecutor
    self.cancellationHandler = cancellationHandler
  }

  public func execute(
    directoryURL: URL,
    timeout: TimeInterval,
    itemStarted: @escaping (ScriptCollectionItem) -> Void = { _ in },
    progressHandler: @escaping (ScriptCollectionItem, ScriptProgressSnapshot) -> Void = { _, _ in },
    itemCompleted: @escaping (ScriptCollectionItem, ScriptExecutionResult) async -> Void = { _, _ in }
  ) async throws -> ScriptCollectionExecutionReport {
    let items = discovery.scripts(in: directoryURL)
    guard !items.isEmpty else {
      throw ScriptCollectionRunnerError.noSupportedScripts
    }

    let startedAt = Date()
    var entries: [ScriptCollectionEntryResult] = []
    for item in items {
      if Task.isCancelled { break }
      itemStarted(item)
      let result = await execute(item: item, timeout: timeout) { snapshot in
        progressHandler(item, snapshot)
      }
      entries.append(ScriptCollectionEntryResult(relativePath: item.relativePath, result: result))
      await itemCompleted(item, result)
      if result.status == .cancelled { break }
    }

    return ScriptCollectionExecutionReport(
      mode: .automatically,
      directoryPath: directoryURL.path(percentEncoded: false),
      startedAt: startedAt,
      completedAt: Date(),
      entries: entries
    )
  }

  public func executeInteractively(
    directoryURL: URL,
    timeout: TimeInterval,
    itemStarted: @escaping (ScriptCollectionItem) -> Void = { _ in },
    progressHandler: @escaping (ScriptCollectionItem, ScriptProgressSnapshot) -> Void = { _, _ in },
    itemCompleted: @escaping (ScriptCollectionItem, ScriptExecutionResult) async -> Void = { _, _ in },
    actionProvider: @escaping (ScriptCollectionInteractiveStep) async -> ScriptCollectionInteractiveAction
  ) async throws -> ScriptCollectionInteractiveOutcome {
    let items = discovery.scripts(in: directoryURL)
    guard !items.isEmpty else {
      throw ScriptCollectionRunnerError.noSupportedScripts
    }

    let startedAt = Date()
    var entries: [ScriptCollectionEntryResult] = []
    var itemIndex = 0
    var completion = ScriptCollectionInteractiveCompletion.finished
    while items.indices.contains(itemIndex) {
      let item = items[itemIndex]
      itemStarted(item)
      let result = await execute(item: item, timeout: timeout) { snapshot in
        progressHandler(item, snapshot)
      }
      entries.append(ScriptCollectionEntryResult(relativePath: item.relativePath, result: result))
      await itemCompleted(item, result)
      let nextItem = items.indices.contains(itemIndex + 1) ? items[itemIndex + 1] : nil
      let action = await actionProvider(
        ScriptCollectionInteractiveStep(item: item, result: result, nextItem: nextItem)
      )
      switch action {
      case .runAgain:
        continue
      case .runNext:
        itemIndex += 1
      case .quit:
        completion = .quit
        itemIndex = items.count
      }
    }

    let report = ScriptCollectionExecutionReport(
      mode: .interactively,
      directoryPath: directoryURL.path(percentEncoded: false),
      startedAt: startedAt,
      completedAt: Date(),
      entries: entries
    )
    return ScriptCollectionInteractiveOutcome(report: report, completion: completion)
  }

  public func cancel() {
    currentExecutionTask?.cancel()
    cancellationHandler()
  }

  private func execute(
    item: ScriptCollectionItem,
    timeout: TimeInterval,
    progressHandler: @escaping (ScriptProgressSnapshot) -> Void
  ) async -> ScriptExecutionResult {
    let task = Task<ScriptExecutionResult, Never> { @MainActor [requestExecutor] in
      let startedAt = Date()
      let request: ScriptExecutionRequest
      do {
        request = try ScriptExecutionRequest(
          scriptURL: item.url,
          identity: .inferred(from: item.url)
        )
      } catch {
        return .failure(
          requestID: UUID(),
          message: "The script could not be prepared. \(error.localizedDescription)",
          startedAt: startedAt
        )
      }
      do {
        return try await requestExecutor(request, timeout) { snapshot in
          var snapshot = snapshot
          snapshot.scriptIdentity = request.identity
          progressHandler(snapshot)
        }
      } catch let error as ScriptHelperProcessError {
        return .failure(
          requestID: request.requestID,
          status: Self.executionStatus(for: error),
          message: error.localizedDescription,
          startedAt: startedAt
        )
      } catch {
        return .failure(
          requestID: request.requestID,
          message: error.localizedDescription,
          startedAt: startedAt
        )
      }
    }
    currentExecutionTask = task
    let result = await task.value
    currentExecutionTask = nil
    return result
  }

  private static func executionStatus(for error: ScriptHelperProcessError) -> ScriptExecutionStatus {
    switch error {
    case .cancelled: .cancelled
    case .timedOut: .timedOut
    default: .failed
    }
  }
}

public struct ScriptCollectionInteractiveStep: Sendable {
  public var item: ScriptCollectionItem
  public var result: ScriptExecutionResult
  public var nextItem: ScriptCollectionItem?

  public init(
    item: ScriptCollectionItem,
    result: ScriptExecutionResult,
    nextItem: ScriptCollectionItem?
  ) {
    self.item = item
    self.result = result
    self.nextItem = nextItem
  }
}

public enum ScriptCollectionInteractiveAction: Equatable, Sendable {
  case runAgain
  case runNext
  case quit
}

public struct ScriptCollectionInteractiveOutcome: Sendable {
  public var report: ScriptCollectionExecutionReport
  public var completion: ScriptCollectionInteractiveCompletion

  public init(
    report: ScriptCollectionExecutionReport,
    completion: ScriptCollectionInteractiveCompletion
  ) {
    self.report = report
    self.completion = completion
  }
}

public enum ScriptCollectionInteractiveCompletion: Equatable, Sendable {
  case finished
  case quit
}

public enum ScriptCollectionRunnerError: LocalizedError, Equatable, Sendable {
  case noSupportedScripts

  public var errorDescription: String? {
    "No supported scripts were found in the specified directory."
  }
}
