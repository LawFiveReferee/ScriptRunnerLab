import Foundation
import ScriptRunnerKit
import XCTest

final class ScriptExecutionLogTests: XCTestCase {
  func testWriterAppendsPortableJSONLines() async throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "ScriptRunnerKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directoryURL) }
    let logURL = directoryURL.appending(path: "ExecutionLog.jsonl")
    let writer = ScriptExecutionLogWriter(fileURL: logURL)
    let entry = makeEntry()

    try await writer.append(entry)
    try await writer.append(entry)

    let lines = try String(contentsOf: logURL, encoding: .utf8)
      .split(separator: "\n")
    XCTAssertEqual(lines.count, 2)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(ScriptExecutionLogEntry.self, from: Data(lines[0].utf8))
    XCTAssertEqual(decoded.schemaVersion, 1)
    XCTAssertEqual(decoded.script.name, "Test.applescript")
    XCTAssertEqual(decoded.result.status, .completed)
  }

  private func makeEntry() -> ScriptExecutionLogEntry {
    let now = Date()
    return ScriptExecutionLogEntry(
      host: .init(name: "Test Host", bundleIdentifier: "org.example.test", version: "1.0", build: "1"),
      script: .init(
        name: "Test.applescript",
        path: "/tmp/Test.applescript",
        fileExtension: "applescript",
        typeIdentifier: "com.apple.applescript.text",
        scriptType: .sourceAppleScript,
        isPackage: false
      ),
      environment: .init(
        operatingSystem: "macOS Test",
        architecture: "Test",
        isSandboxed: false,
        isolation: "Test Helper"
      ),
      engine: .osaKit,
      result: ScriptExecutionResult(
        requestID: UUID(),
        status: .completed,
        sourceResultDescription: "ok",
        rawResultDescription: "\"ok\"",
        errorNumber: nil,
        errorMessage: nil,
        errorBriefMessage: nil,
        errorRange: nil,
        executionDuration: 0.1,
        startedAt: now,
        completedAt: now
      )
    )
  }
}
