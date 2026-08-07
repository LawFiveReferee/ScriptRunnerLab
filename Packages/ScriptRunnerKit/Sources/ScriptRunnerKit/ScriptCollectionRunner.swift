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
  private var helperRunner: ScriptHelperProcessRunner
  private var discovery: ScriptCollectionDiscovery

  public init(
    helperRunner: ScriptHelperProcessRunner,
    discovery: ScriptCollectionDiscovery = ScriptCollectionDiscovery()
  ) {
    self.helperRunner = helperRunner
    self.discovery = discovery
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

  public func cancel() {
    helperRunner.cancel()
  }

  private func execute(
    item: ScriptCollectionItem,
    timeout: TimeInterval,
    progressHandler: @escaping (ScriptProgressSnapshot) -> Void
  ) async -> ScriptExecutionResult {
    let startedAt = Date()
    let request: ScriptExecutionRequest
    do {
      request = try ScriptExecutionRequest(scriptURL: item.url)
    } catch {
      return .failure(
        requestID: UUID(),
        message: "The script could not be prepared. \(error.localizedDescription)",
        startedAt: startedAt
      )
    }
    do {
      return try await helperRunner.execute(
        request: request,
        timeout: timeout,
        progressHandler: progressHandler
      )
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

  private static func executionStatus(for error: ScriptHelperProcessError) -> ScriptExecutionStatus {
    switch error {
    case .cancelled: .cancelled
    case .timedOut: .timedOut
    default: .failed
    }
  }
}

public enum ScriptCollectionRunnerError: LocalizedError, Equatable, Sendable {
  case noSupportedScripts

  public var errorDescription: String? {
    "No supported scripts were found in the specified directory."
  }
}
