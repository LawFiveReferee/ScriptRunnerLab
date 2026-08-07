import XCTest
@testable import ScriptRunnerKit

final class ScriptCapabilityTests: XCTestCase {
  func testCapabilityDecodesExistingFavoriteMetadata() throws {
    let data = Data(#"{"kind":"framework","detail":"Foundation"}"#.utf8)

    let capability = try JSONDecoder().decode(ScriptCapability.self, from: data)

    XCTAssertEqual(capability, ScriptCapability(kind: .framework, detail: "Foundation"))
  }

  func testSourceAnalyzerDetectsHostRelevantCapabilitiesAndDetails() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "ScriptCapabilityTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let scriptURL = directory.appending(path: "Capabilities.applescript")
    let source = """
    use framework "Foundation"
    use script "Example Library"
    use scripting additions
    tell application "Finder" to get name
    display dialog "Test"
    set progress total steps to 1
    set scriptPath to path to me
    set resourcePath to path to resource "payload.txt"
    """
    try Data(source.utf8).write(to: scriptURL)

    let capabilities = ScriptCapability.detect(in: ScriptDescriptor(url: scriptURL))

    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .applicationAutomation)))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .framework, detail: "Foundation")))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .scriptLibrary, detail: "Example Library")))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .scriptingAdditions)))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .userInterface)))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .builtInProgress)))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .pathToMe)))
    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .bundledResources)))
  }

  func testPackagedScriptBundleIsTaggedForBundledResources() throws {
    let rootURL = try XCTUnwrap(CompatibilityTestResources.rootURL)
    let bundleURL = rootURL.appending(path: "Artifacts/BundleResource.scptd")

    let capabilities = ScriptCapability.detect(in: ScriptDescriptor(url: bundleURL))

    XCTAssertTrue(capabilities.contains(ScriptCapability(kind: .bundledResources)))
  }
}
