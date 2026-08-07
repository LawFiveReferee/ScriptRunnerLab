import Foundation
import ScriptRunnerKit
import XCTest

final class ScriptDescriptorTests: XCTestCase {
  func testRecognizesAppleScriptAppletStructure() throws {
    let appURL = try temporaryApplication(withMainScript: true)
    defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

    let descriptor = ScriptDescriptor(url: appURL)

    XCTAssertEqual(descriptor.scriptType, .appleScriptApplet)
    XCTAssertTrue(descriptor.isPackage)
    XCTAssertTrue(descriptor.isCompiled)
  }

  func testRejectsOrdinaryApplicationBundle() throws {
    let appURL = try temporaryApplication(withMainScript: false)
    defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

    XCTAssertEqual(ScriptDescriptor(url: appURL).scriptType, .unsupported)
  }

  private func temporaryApplication(withMainScript: Bool) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "ScriptRunnerKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let appURL = directoryURL.appending(path: "Test.app", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

    if withMainScript {
      let scriptsURL = appURL.appending(path: "Contents/Resources/Scripts", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: scriptsURL, withIntermediateDirectories: true)
      try Data().write(to: scriptsURL.appending(path: "main.scpt"))
    }
    return appURL
  }
}
