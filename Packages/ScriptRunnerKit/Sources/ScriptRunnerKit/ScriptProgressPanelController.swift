import AppKit
import SwiftUI

public enum ScriptProgressPresentationMode: Sendable {
  case attached
  case floating
}

public enum ScriptProgressFooterAlignment: Equatable, Sendable {
  case leading
  case center
  case trailing
}

@MainActor
public struct ScriptProgressPanelFooter {
  public var icon: NSImage?
  public var text: String?
  public var alignment: ScriptProgressFooterAlignment

  public init(
    icon: NSImage? = nil,
    text: String? = nil,
    alignment: ScriptProgressFooterAlignment = .leading
  ) {
    self.icon = icon
    self.text = text
    self.alignment = alignment
  }
}

@MainActor
public struct ScriptProgressPanelConfiguration {
  public var contentSize: NSSize
  public var windowTitle: @MainActor (ScriptExecutionIdentity?) -> String
  public var footer: ScriptProgressPanelFooter?

  public init(
    contentSize: NSSize = NSSize(width: 360, height: 142),
    windowTitle: @escaping @MainActor (ScriptExecutionIdentity?) -> String = { _ in
      "Script Progress"
    },
    footer: ScriptProgressPanelFooter? = nil
  ) {
    self.contentSize = contentSize
    self.windowTitle = windowTitle
    self.footer = footer
  }

  public static var `default`: ScriptProgressPanelConfiguration {
    ScriptProgressPanelConfiguration()
  }
}

@MainActor
public final class ScriptProgressPanelController {
  public var configuration: ScriptProgressPanelConfiguration

  private var panel: NSPanel?
  private weak var parentWindow: NSWindow?

  public init() {
    self.configuration = ScriptProgressPanelConfiguration()
  }

  public init(configuration: ScriptProgressPanelConfiguration) {
    self.configuration = configuration
  }

  public func present(
    _ snapshot: ScriptProgressSnapshot,
    mode: ScriptProgressPresentationMode,
    relativeTo parentWindow: NSWindow? = nil,
    onCancel: @escaping @MainActor () -> Void
  ) {
    present(
      snapshot,
      identity: snapshot.scriptIdentity,
      mode: mode,
      relativeTo: parentWindow,
      onCancel: onCancel
    )
  }

  public func present(
    _ snapshot: ScriptProgressSnapshot,
    identity: ScriptExecutionIdentity?,
    mode: ScriptProgressPresentationMode,
    relativeTo parentWindow: NSWindow? = nil,
    onCancel: @escaping @MainActor () -> Void
  ) {
    let panel = panel ?? makePanel()
    panel.title = configuration.windowTitle(identity)
    panel.contentView = NSHostingView(
      rootView: ScriptProgressPanelContent(
        snapshot: snapshot,
        footer: configuration.footer,
        contentSize: configuration.contentSize,
        onCancel: onCancel
      )
    )
    panel.setContentSize(configuration.contentSize)

    if self.parentWindow !== parentWindow {
      self.parentWindow?.removeChildWindow(panel)
      self.parentWindow = nil
    }

    switch mode {
    case .attached:
      panel.level = .normal
      if let parentWindow, panel.parent == nil {
        parentWindow.addChildWindow(panel, ordered: .above)
        self.parentWindow = parentWindow
      } else if parentWindow == nil {
        panel.orderFront(nil)
      }
    case .floating:
      panel.parent?.removeChildWindow(panel)
      self.parentWindow = nil
      panel.level = .floating
      panel.orderFrontRegardless()
    }
  }

  public func dismiss() {
    guard let panel else { return }
    parentWindow?.removeChildWindow(panel)
    parentWindow = nil
    panel.orderOut(nil)
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 142),
      styleMask: [.titled, .utilityWindow],
      backing: .buffered,
      defer: false
    )
    panel.title = configuration.windowTitle(nil)
    panel.isReleasedWhenClosed = false
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.center()
    self.panel = panel
    return panel
  }
}

private struct ScriptProgressPanelContent: View {
  var snapshot: ScriptProgressSnapshot
  var footer: ScriptProgressPanelFooter?
  var contentSize: NSSize
  var onCancel: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(snapshot.progressDescription ?? "Running AppleScript")
        .font(.headline)
        .lineLimit(1)

      if snapshot.isIndeterminate {
        ProgressView()
          .progressViewStyle(.linear)
      } else {
        ProgressView(value: snapshot.fractionCompleted)
          .progressViewStyle(.linear)
      }

      HStack(alignment: .firstTextBaseline) {
        Text(detailText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Spacer()
        Button("Cancel", role: .cancel) {
          onCancel()
        }
        .keyboardShortcut(.cancelAction)
      }

      if let footer {
        footerView(footer)
      }
    }
    .padding(16)
    .frame(width: contentSize.width, height: contentSize.height)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("AppleScript progress")
  }

  @ViewBuilder
  private func footerView(_ footer: ScriptProgressPanelFooter) -> some View {
    HStack(spacing: 6) {
      if footer.alignment != .leading { Spacer(minLength: 0) }
      if let icon = footer.icon {
        Image(nsImage: icon)
          .resizable()
          .scaledToFit()
          .frame(width: 16, height: 16)
      }
      if let text = footer.text {
        Text(text)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if footer.alignment != .trailing { Spacer(minLength: 0) }
    }
    .accessibilityElement(children: .combine)
  }

  private var detailText: String {
    if let additionalDescription = snapshot.additionalDescription {
      return additionalDescription
    }
    guard !snapshot.isIndeterminate, snapshot.totalSteps > 0 else {
      return "Working…"
    }
    return "\(snapshot.completedSteps) of \(snapshot.totalSteps)"
  }
}
