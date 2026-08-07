import AppKit
import SwiftUI

public enum ScriptProgressPresentationMode: Sendable {
  case attached
  case floating
}

@MainActor
public final class ScriptProgressPanelController {
  private var panel: NSPanel?
  private weak var parentWindow: NSWindow?

  public init() {}

  public func present(
    _ snapshot: ScriptProgressSnapshot,
    mode: ScriptProgressPresentationMode,
    relativeTo parentWindow: NSWindow? = nil,
    onCancel: @escaping @MainActor () -> Void
  ) {
    let panel = panel ?? makePanel()
    panel.contentView = NSHostingView(
      rootView: ScriptProgressPanelContent(snapshot: snapshot, onCancel: onCancel)
    )
    panel.setContentSize(NSSize(width: 360, height: 142))

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
    panel.title = "Script Progress"
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
    }
    .padding(16)
    .frame(width: 360, height: 142)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("AppleScript progress")
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
