import AppKit
import XCTest
@testable import ScriptRunnerKit

final class ScriptProgressPanelConfigurationTests: XCTestCase {
  @MainActor
  func testDefaultConfigurationPreservesExistingPresentation() {
    let configuration = ScriptProgressPanelConfiguration.default

    XCTAssertEqual(configuration.contentSize, NSSize(width: 360, height: 142))
    XCTAssertEqual(configuration.windowTitle(nil), "Script Progress")
    XCTAssertNil(configuration.footer)
  }

  @MainActor
  func testCustomizedConfigurationUsesLogicalNameAndFooter() throws {
    let icon = NSImage(size: NSSize(width: 16, height: 16))
    let configuration = ScriptProgressPanelConfiguration(
      contentSize: NSSize(width: 380, height: 176),
      windowTitle: { identity in identity?.displayName ?? "Host Progress" },
      footer: ScriptProgressPanelFooter(
        icon: icon,
        text: "Example Host",
        alignment: .trailing
      )
    )

    XCTAssertEqual(
      configuration.windowTitle(ScriptExecutionIdentity(displayName: "Logical Script")),
      "Logical Script"
    )
    XCTAssertEqual(configuration.footer?.text, "Example Host")
    XCTAssertEqual(configuration.footer?.alignment, .trailing)
    XCTAssertTrue(configuration.footer?.icon === icon)
  }
}
