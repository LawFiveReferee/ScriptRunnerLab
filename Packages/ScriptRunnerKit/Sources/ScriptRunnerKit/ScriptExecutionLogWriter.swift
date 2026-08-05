import Foundation

public actor ScriptExecutionLogWriter {
  public let fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func append(_ entry: ScriptExecutionLogEntry) throws {
    let fileManager = FileManager.default
    let directoryURL = fileURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    if !fileManager.fileExists(atPath: fileURL.path) {
      guard fileManager.createFile(atPath: fileURL.path, contents: nil) else {
        throw CocoaError(.fileWriteUnknown)
      }
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(entry)
    data.append(0x0A)

    let handle = try FileHandle(forWritingTo: fileURL)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: data)
  }
}
