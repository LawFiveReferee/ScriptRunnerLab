import Foundation

@MainActor
public final class ScriptRunnerService {
  public let configuration: ScriptRunnerHostConfiguration

  private var collectionRunner: ScriptCollectionRunner
  private var requestExecutor: (
    ScriptExecutionRequest,
    TimeInterval,
    @escaping (ScriptProgressSnapshot) -> Void
  ) async throws -> ScriptExecutionResult
  private var cancellationHandler: () -> Void
  private var logWriter: ScriptExecutionLogWriter?
  private var currentExecutionTask: Task<ScriptExecutionResult, Never>?

  public init(configuration: ScriptRunnerHostConfiguration) {
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
    requestExecutor: @escaping (
      ScriptExecutionRequest,
      TimeInterval,
      @escaping (ScriptProgressSnapshot) -> Void
    ) async throws -> ScriptExecutionResult,
    cancellationHandler: @escaping () -> Void = {}
  ) {
    self.configuration = configuration
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
    let task = Task<ScriptExecutionResult, Never> { @MainActor [weak self] in
      guard let self else {
        return .failure(requestID: UUID(), message: "The script runner is unavailable.")
      }
      return await performExecution(
        scriptURL: scriptURL,
        timeout: timeout,
        progressHandler: progressHandler
      )
    }
    currentExecutionTask = task
    let result = await task.value
    currentExecutionTask = nil
    return result
  }

  public func executeAutomatically(
    directoryURL: URL,
    timeout: TimeInterval,
    itemStarted: @escaping (ScriptCollectionItem) -> Void = { _ in },
    progressHandler: @escaping (ScriptCollectionItem, ScriptProgressSnapshot) -> Void = { _, _ in },
    itemCompleted: @escaping (ScriptCollectionItem, ScriptExecutionResult) async -> Void = { _, _ in }
  ) async throws -> ScriptCollectionExecutionReport {
    try await collectionRunner.execute(
      directoryURL: directoryURL,
      timeout: timeout,
      itemStarted: itemStarted,
      progressHandler: progressHandler
    ) { [weak self] item, result in
      await self?.record(descriptor: item.descriptor, result: result)
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
    try await collectionRunner.executeInteractively(
      directoryURL: directoryURL,
      timeout: timeout,
      itemStarted: itemStarted,
      progressHandler: progressHandler,
      itemCompleted: { [weak self] item, result in
        await self?.record(descriptor: item.descriptor, result: result)
        await itemCompleted(item, result)
      },
      actionProvider: actionProvider
    )
  }

  public func cancel() {
    currentExecutionTask?.cancel()
    collectionRunner.cancel()
    cancellationHandler()
  }

  private func performExecution(
    scriptURL: URL,
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
      request = try ScriptExecutionRequest(scriptURL: scriptURL)
    } catch {
      let result = ScriptExecutionResult.failure(
        requestID: UUID(),
        message: "The script could not be prepared. \(error.localizedDescription)",
        startedAt: startedAt
      )
      await record(descriptor: ScriptDescriptor(url: scriptURL), result: result)
      return result
    }

    let result: ScriptExecutionResult
    do {
      result = try await requestExecutor(request, timeout, progressHandler)
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
    await record(descriptor: ScriptDescriptor(url: scriptURL), result: result)
    return result
  }

  private func record(descriptor: ScriptDescriptor, result: ScriptExecutionResult) async {
    guard let logWriter else { return }
    let entry = ScriptExecutionLogEntry(
      host: configuration.host,
      script: .init(
        name: descriptor.displayName,
        path: descriptor.url.path(percentEncoded: false),
        fileExtension: descriptor.fileExtension,
        typeIdentifier: descriptor.typeIdentifier,
        scriptType: descriptor.scriptType,
        isPackage: descriptor.isPackage
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
}
