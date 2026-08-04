import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @State private var runner = ScriptRunnerModel()
  @State private var isChoosingScript = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header
          scriptCard
          executionCard
          diagnosticsCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
      }
      .navigationTitle("Script Runner Lab")
      .toolbar {
        ToolbarItemGroup {
          Button("Choose Script", systemImage: "doc.badge.plus") {
            isChoosingScript = true
          }
          Button("Run", systemImage: "play.fill") {
            runner.run()
          }
          .disabled(!runner.canRun)
        }
      }
      .fileImporter(
        isPresented: $isChoosingScript,
        allowedContentTypes: [.item],
        allowsMultipleSelection: false
      ) { result in
        runner.receiveSelection(result)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Native AppleScript execution", systemImage: "applescript")
        .font(.title2.bold())
      Text("Loads the original script with OSAKit so compiled context, bundles, resources, and “path to me” remain intact.")
        .foregroundStyle(.secondary)
    }
  }

  private var scriptCard: some View {
    GroupBox("Selected Script") {
      if let descriptor = runner.descriptor {
        VStack(alignment: .leading, spacing: 12) {
          detailRow("Name", descriptor.displayName)
          detailRow("Location", descriptor.url.path(percentEncoded: false))
          detailRow("Type", descriptor.scriptType.displayName)
          detailRow("Extension", descriptor.fileExtension.isEmpty ? "None" : ".\(descriptor.fileExtension)")
          detailRow("Package", descriptor.isPackage ? "Yes" : "No")

          HStack {
            Button("Reveal in Finder", systemImage: "folder") {
              runner.revealScript()
            }
            Button("Open in Script Editor", systemImage: "pencil.and.scribble") {
              runner.openInScriptEditor()
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
      } else {
        ContentUnavailableView(
          "No Script Selected",
          systemImage: "doc.text.magnifyingglass",
          description: Text("Choose an .applescript, .scpt, or .scptd file to begin.")
        )
        .frame(maxWidth: .infinity, minHeight: 150)
      }
    }
  }

  private var executionCard: some View {
    GroupBox("Execution") {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          statusLabel
          Spacer()
          if runner.isRunning {
            ProgressView()
              .controlSize(.small)
          }
          Text(runner.durationText)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }

        TextEditor(text: .constant(runner.outputText))
          .font(.system(.body, design: .monospaced))
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 150)
          .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
          .accessibilityLabel("Execution result")

        HStack {
          Button("Run Again", systemImage: "arrow.clockwise") {
            runner.run()
          }
          .disabled(!runner.canRun)
          Button("Copy Result", systemImage: "document.on.document") {
            runner.copyResult()
          }
          .disabled(runner.result == nil)
          Button("Clear", systemImage: "xmark") {
            runner.clearResult()
          }
          .disabled(runner.result == nil)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 8)
    }
  }

  private var diagnosticsCard: some View {
    GroupBox("Diagnostics") {
      Text(runner.diagnosticsText)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
  }

  private var statusLabel: some View {
    Label(runner.status.displayName, systemImage: runner.status.symbolName)
      .foregroundStyle(runner.status.color)
      .font(.headline)
  }

  private func detailRow(_ title: String, _ value: String) -> some View {
    LabeledContent(title) {
      Text(value)
        .lineLimit(2)
        .textSelection(.enabled)
    }
  }
}
