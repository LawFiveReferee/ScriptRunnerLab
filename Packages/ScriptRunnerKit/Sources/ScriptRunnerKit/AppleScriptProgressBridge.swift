import Foundation
import OSAKit

final class AppleScriptProgressBridge {
  typealias Handler = (ScriptProgressSnapshot) -> Void

  private let requestID: UUID
  private let progressURL: URL
  private let handler: Handler
  private let timer: DispatchSourceTimer
  private let lock = NSLock()
  private var lastData: Data?

  private init(requestID: UUID, progressURL: URL, handler: @escaping Handler) {
    self.requestID = requestID
    self.progressURL = progressURL
    self.handler = handler
    timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "ScriptRunnerKit.Progress"))
  }

  deinit {
    try? FileManager.default.removeItem(at: progressURL.deletingLastPathComponent())
  }

  static func prepare(
    script: OSAScript,
    originalURL: URL,
    requestID: UUID,
    handler: @escaping Handler
  ) -> (script: OSAScript, bridge: AppleScriptProgressBridge)? {
    let source = script.source
    guard containsProgressSetter(in: source) else { return nil }

    let directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "ScriptRunnerKitProgress-\(requestID.uuidString)", directoryHint: .isDirectory)
    let progressURL = directoryURL.appending(path: "progress.json", directoryHint: .notDirectory)

    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    } catch {
      return nil
    }

    let instrumentedSource = instrument(source, progressURL: progressURL)
    let instrumentedScript = OSAScript(
      source: instrumentedSource,
      from: originalURL,
      languageInstance: script.languageInstance,
      using: []
    )
    var compileError: NSDictionary?
    guard instrumentedScript.compileAndReturnError(&compileError) else {
      try? FileManager.default.removeItem(at: directoryURL)
      return nil
    }

    let bridge = AppleScriptProgressBridge(
      requestID: requestID,
      progressURL: progressURL,
      handler: handler
    )
    return (instrumentedScript, bridge)
  }

  func start() {
    timer.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(10))
    timer.setEventHandler { [weak self] in
      self?.publishLatest()
    }
    timer.resume()
  }

  func stop() {
    publishLatest()
    timer.setEventHandler {}
    timer.cancel()
  }

  private func publishLatest() {
    guard let data = try? Data(contentsOf: progressURL) else { return }
    lock.lock()
    defer { lock.unlock() }
    guard data != lastData else { return }
    lastData = data
    guard let payload = try? JSONDecoder().decode(ProgressPayload.self, from: data) else { return }
    handler(
      ScriptProgressSnapshot(
        requestID: requestID,
        totalSteps: payload.totalSteps,
        completedSteps: payload.completedSteps,
        progressDescription: payload.progressDescription,
        additionalDescription: payload.additionalDescription
      )
    )
  }

  private static func containsProgressSetter(in source: String) -> Bool {
    source.range(
      of: #"(?im)^\s*set\s+progress\s+(total\s+steps|completed\s+steps|description|additional\s+description)\s+to\b"#,
      options: .regularExpression
    ) != nil
  }

  private static func instrument(_ source: String, progressURL: URL) -> String {
    let pattern = #"(?i)^(\s*)set\s+progress\s+(total\s+steps|completed\s+steps|description|additional\s+description)\s+to\b"#
    let lines = source.components(separatedBy: .newlines)
    var instrumentedLines: [String] = []

    for line in lines {
      instrumentedLines.append(line)
      guard line.range(of: pattern, options: .regularExpression) != nil else { continue }
      let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
      instrumentedLines.append("\(indentation)my __scriptRunnerReportProgress()")
    }

    let escapedPath = progressURL.path(percentEncoded: false)
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return """
    use framework "Foundation"

    \(instrumentedLines.joined(separator: "\n"))

    on __scriptRunnerReportProgress()
      set progressValues to {progress total steps, progress completed steps, progress description as text, progress additional description as text}
      set progressKeys to {"totalSteps", "completedSteps", "progressDescription", "additionalDescription"}
      set progressDictionary to current application's NSDictionary's dictionaryWithObjects:progressValues forKeys:progressKeys
      set progressData to current application's NSJSONSerialization's dataWithJSONObject:progressDictionary options:0 |error|:(missing value)
      set progressFileURL to current application's NSURL's fileURLWithPath:"\(escapedPath)"
      progressData's writeToURL:progressFileURL options:(current application's NSDataWritingAtomic) |error|:(missing value)
    end __scriptRunnerReportProgress
    """
  }
}

private struct ProgressPayload: Decodable {
  var totalSteps: Int64
  var completedSteps: Int64
  var progressDescription: String
  var additionalDescription: String
}
