import Foundation

@MainActor
public final class ScriptRunnerService {
  public let configuration: ScriptRunnerHostConfiguration
  public let overlapPolicy: ScriptExecutionOverlapPolicy

  public var isBusy: Bool {
    activeOperationID != nil
  }

  private var collectionRunner: ScriptCollectionRunner
  private var requestExecutor: (
    ScriptExecutionRequest,
    TimeInterval,
    @escaping (ScriptProgressSnapshot) -> Void
  ) async throws -> ScriptExecutionResult
  private var cancellationHandler: () -> Void
  private var logWriter: ScriptExecutionLogWriter?
  private var currentExecutionTask: Task<ScriptExecutionResult, Never>?
  private var activeOperationID: UUID?
  private var activeOperationKind: ActiveOperationKind?

  public init(
    configuration: ScriptRunnerHostConfiguration,
    overlapPolicy: ScriptExecutionOverlapPolicy = .rejectNew
  ) {
    let helperRunner = ScriptHelperProcessRunner(
      helperExecutableURL: configuration.helperExecutableURL,
      workingDirectoryName: configuration.workingDirectoryName
    )
    let requestExecutor: (
      ScriptExecutionRequest,
      TimeInterval,
      @escaping (ScriptProgressSnapshot) -> Void
    ) async throws -> ScriptExecutionResult = { request, timeout, progressHandler in
      try await helperRunner.execute(
        request: request,
        timeout: timeout,
        progressHandler: progressHandler
      )
    }
    self.configuration = configuration
    self.overlapPolicy = overlapPolicy
    self.requestExecutor = requestExecutor
    self.cancellationHandler = helperRunner.cancel
    self.collectionRunner = ScriptCollectionRunner(
      requestExecutor: requestExecutor,
      cancellationHandler: helperRunner.cancel
    )
    self.logWriter = configuration.logURL.map(ScriptExecutionLogWriter.init(fileURL:))
  }

  init(
    configuration: ScriptRunnerHostConfiguration,
    overlapPolicy: ScriptExecutionOverlapPolicy = .rejectNew,
    requestExecutor: @escaping (
      ScriptExecutionRequest,
      TimeInterval,
      @escaping (ScriptProgressSnapshot) -> Void
    ) async throws -> ScriptExecutionResult,
    cancellationHandler: @escaping () -> Void = {}
  ) {
    self.configuration = configuration
    self.overlapPolicy = overlapPolicy
    self.requestExecutor = requestExecutor
    self.cancellationHandler = cancellationHandler
    self.collectionRunner = ScriptCollectionRunner(
      requestExecutor: requestExecutor,
      cancellationHandler: cancellationHandler
    )
    self.logWriter = configuration.logURL.map(ScriptExecutionLogWriter.init(fileURL:))
  }

  public func execute(
    scriptURL: URL,
    timeout: TimeInterval,
    progressHandler: @escaping (ScriptProgressSnapshot) -> Void = { _ in }
  ) async -> ScriptExecutionResult {
    await execute(
      scriptURL: scriptURL,
      identity: .inferred(from: scriptURL),
      timeout: timeout,
      progressHandler: progressHandler
    )
  }

  public func execute(
    scriptURL: URL,
    identity: ScriptExecutionIdentity,
    timeout: TimeInterval,
    progressHandler: @escaping (ScriptProgressSnapshot) -> Void = { _ in }
  ) async -> ScriptExecutionResult {
    let operationID = UUID()
    guard acquire(operationID, kind: .single) else {
      let result = ScriptExecutionResult.failure(
        requestID: UUID(),
        status: .busy,
        message: "\(identity.displayName) was not started because the script runner is busy."
      )
      await record(descriptor: ScriptDescriptor(url: scriptURL), identity: identity, result: result)
      return result
    }
    defer { release(operationID) }

    let task = Task<ScriptExecutionResult, Never> { @MainActor [weak self] in
      guard let self else {
        return .failure(requestID: UUID(), message: "The script runner is unavailable.")
      }
      return await performExecution(
        scriptURL: scriptURL,
        identity: identity,
        timeout: timeout,
        progressHandler: progressHandler
      )
    }
    currentExecutionTask = task
    let result = await task.value
    if activeOperationID == operationID {
      currentExecutionTask = nil
    }
    return result
  }

  public func executeAutomatically(
    directoryURL: URL,
    timeout: TimeInterval,
    itemStarted: @escaping (ScriptCollectionItem) -> Void = { _ in },
    progressHandler: @escaping (ScriptCollectionItem, ScriptProgressSnapshot) -> Void = { _, _ in },
    itemCompleted: @escaping (ScriptCollectionItem, ScriptExecutionResult) async -> Void = { _, _ in }
  ) async throws -> ScriptCollectionExecutionReport {
    let operationID = UUID()
    guard acquire(operationID, kind: .collection) else { throw ScriptRunnerServiceError.busy }
    defer { release(operationID) }

    return try await collectionRunner.execute(
      directoryURL: directoryURL,
      timeout: timeout,
      itemStarted: itemStarted,
      progressHandler: progressHandler
    ) { [weak self] item, result in
      await self?.record(
        descriptor: item.descriptor,
        identity: .inferred(from: item.url),
        result: result
      )
      await itemCompleted(item, result)
    }
  }

  public func executeInteractively(
    directoryURL: URL,
    timeout: TimeInterval,
    itemStarted: @escaping (ScriptCollectionItem) -> Void = { _ in },
    progressHandler: @escaping (ScriptCollectionItem, ScriptProgressSnapshot) -> Void = { _, _ in },
    itemCompleted: @escaping (ScriptCollectionItem, ScriptExecutionResult) async -> Void = { _, _ in },
    actionProvider: @escaping (ScriptCollectionInteractiveStep) async -> ScriptCollectionInteractiveAction
  ) async throws -> ScriptCollectionInteractiveOutcome {
    let operationID = UUID()
    guard acquire(operationID, kind: .collection) else { throw ScriptRunnerServiceError.busy }
    defer { release(operationID) }

    return try await collectionRunner.executeInteractively(
      directoryURL: directoryURL,
      timeout: timeout,
      itemStarted: itemStarted,
      progressHandler: progressHandler,
      itemCompleted: { [weak self] item, result in
        await self?.record(
          descriptor: item.descriptor,
          identity: .inferred(from: item.url),
          result: result
        )
        await itemCompleted(item, result)
      },
      actionProvider: actionProvider
    )
  }

  public func cancel() {
    switch activeOperationKind {
    case .single:
      currentExecutionTask?.cancel()
      cancellationHandler()
    case .collection:
      collectionRunner.cancel()
    case nil:
      break
    }
  }

  private func performExecution(
    scriptURL: URL,
    identity: ScriptExecutionIdentity,
    timeout: TimeInterval,
    progressHandler: @escaping (ScriptProgressSnapshot) -> Void
  ) async -> ScriptExecutionResult {
    let startedAt = Date()
    let accessed = scriptURL.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        scriptURL.stopAccessingSecurityScopedResource()
      }
    }

    let request: ScriptExecutionRequest
    do {
      request = try ScriptExecutionRequest(scriptURL: scriptURL, identity: identity)
    } catch {
      let result = ScriptExecutionResult.failure(
        requestID: UUID(),
        message: "The script could not be prepared. \(error.localizedDescription)",
        startedAt: startedAt
      )
      await record(descriptor: ScriptDescriptor(url: scriptURL), identity: identity, result: result)
      return result
    }

    let result: ScriptExecutionResult
    do {
      result = try await requestExecutor(request, timeout) { snapshot in
        var snapshot = snapshot
        snapshot.scriptIdentity = identity
        progressHandler(snapshot)
      }
    } catch let error as ScriptHelperProcessError {
      result = .failure(
        requestID: request.requestID,
        status: Self.executionStatus(for: error),
        message: error.localizedDescription,
        startedAt: startedAt
      )
    } catch {
      result = .failure(
        requestID: request.requestID,
        message: error.localizedDescription,
        startedAt: startedAt
      )
    }
    await record(descriptor: ScriptDescriptor(url: scriptURL), identity: identity, result: result)
    return result
  }

  private func record(
    descriptor: ScriptDescriptor,
    identity: ScriptExecutionIdentity,
    result: ScriptExecutionResult
  ) async {
    guard let logWriter else { return }
    let logicalDescriptor = identity.originalURL.map(ScriptDescriptor.init(url:)) ?? descriptor
    let entry = ScriptExecutionLogEntry(
      host: configuration.host,
      script: .init(
        name: identity.displayName,
        path: identity.originalURL?.path(percentEncoded: false)
          ?? descriptor.url.path(percentEncoded: false),
        fileExtension: logicalDescriptor.fileExtension,
        typeIdentifier: logicalDescriptor.typeIdentifier,
        scriptType: logicalDescriptor.scriptType,
        isPackage: logicalDescriptor.isPackage
      ),
      environment: configuration.environment,
      engine: descriptor.scriptType == .appleScriptApplet ? .nsWorkspaceApplet : .osaKit,
      result: result
    )
    try? await logWriter.append(entry)
  }

  private static func executionStatus(for error: ScriptHelperProcessError) -> ScriptExecutionStatus {
    switch error {
    case .cancelled: .cancelled
    case .timedOut: .timedOut
    default: .failed
    }
  }

  private func acquire(_ operationID: UUID, kind: ActiveOperationKind) -> Bool {
    switch overlapPolicy {
    case .rejectNew:
      guard activeOperationID == nil else { return false }
      activeOperationID = operationID
      activeOperationKind = kind
      return true
    }
  }

  private func release(_ operationID: UUID) {
    guard activeOperationID == operationID else { return }
    currentExecutionTask = nil
    activeOperationID = nil
    activeOperationKind = nil
  }
}

private enum ActiveOperationKind {
  case single
  case collection
}

public enum ScriptExecutionOverlapPolicy: Equatable, Sendable {
  case rejectNew
}

public enum ScriptRunnerServiceError: LocalizedError, Equatable, Sendable {
  case busy

  public var errorDescription: String? {
    "The script runner is busy with another execution."
  }
}
