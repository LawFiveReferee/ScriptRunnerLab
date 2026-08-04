import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @State private var runner = ScriptRunnerModel()
  @State private var isChoosingScript = false
  @AppStorage("resultDisplayMode") private var resultDisplayMode = ResultDisplayMode.aePrint
  @AppStorage("executionTimeout") private var executionTimeout = ExecutionTimeout.thirtySeconds

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header
          favoritesCard
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
          .disabled(runner.isRunning)
          Button(
            runner.isRunning ? "Cancel" : "Run",
            systemImage: runner.isRunning ? "stop.fill" : "play.fill"
          ) {
            if runner.isRunning {
              runner.cancel()
            } else {
              runner.run(timeout: executionTimeout.seconds)
            }
          }
          .disabled(!runner.isRunning && !runner.canRun)
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
            Toggle(
              isOn: Binding(
                get: { runner.isSelectedScriptFavorite },
                set: { runner.setSelectedScriptFavorite($0) }
              )
            ) {
              Label(
                runner.isSelectedScriptFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: runner.isSelectedScriptFavorite ? "star.fill" : "star"
              )
            }
            .toggleStyle(.button)
            Button("Reveal in Finder", systemImage: "folder") {
              runner.revealScript()
            }
            Button("Open in \(runner.defaultEditorName)", systemImage: "pencil.and.scribble") {
              runner.openInDefaultEditor()
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

        Picker("Result format", selection: $resultDisplayMode) {
          ForEach(ResultDisplayMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)

        Picker("Timeout", selection: $executionTimeout) {
          ForEach(ExecutionTimeout.allCases) { timeout in
            Text(timeout.displayName).tag(timeout)
          }
        }
        .pickerStyle(.menu)
        .disabled(runner.isRunning)

        TextEditor(text: .constant(runner.outputText(for: resultDisplayMode)))
          .font(.system(.body, design: .monospaced))
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 150)
          .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
          .accessibilityLabel("Execution result")

        HStack {
          Button("Run Again", systemImage: "arrow.clockwise") {
            runner.run(timeout: executionTimeout.seconds)
          }
          .disabled(!runner.canRun)
          Button("Copy Result", systemImage: "document.on.document") {
            runner.copyResult(mode: resultDisplayMode)
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

  private var favoritesCard: some View {
    GroupBox("Favorites Collection") {
      if runner.favorites.isEmpty {
        ContentUnavailableView(
          "No Favorite Scripts",
          systemImage: "star",
          description: Text("Select a script and add it to Favorites to keep it ready for compatibility testing.")
        )
        .frame(maxWidth: .infinity, minHeight: 120)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(runner.favorites.enumerated()), id: \.element.id) { index, favorite in
            HStack(spacing: 12) {
              Button {
                runner.selectFavorite(id: favorite.id)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Image(systemName: runner.selectedFavoriteID == favorite.id ? "star.fill" : "doc.text")
                      .foregroundStyle(runner.selectedFavoriteID == favorite.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(favorite.displayName)
                      .font(.headline)
                    Text(favorite.fileExtension.isEmpty ? "Unknown" : ".\(favorite.fileExtension)")
                      .font(.caption.monospaced())
                      .foregroundStyle(.secondary)
                  }
                  Text(favorite.scriptType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(capabilitySummary(for: favorite))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Select favorite \(favorite.displayName)")
              .disabled(runner.isRunning)

              Button("Remove \(favorite.displayName)", systemImage: "trash") {
                runner.removeFavorite(id: favorite.id)
              }
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
            }
            .padding(.vertical, 10)

            if index < runner.favorites.count - 1 {
              Divider()
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
      }
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

  private func capabilitySummary(for favorite: FavoriteScript) -> String {
    guard !favorite.capabilities.isEmpty else { return "No specific capabilities detected in available source" }
    return favorite.capabilities.map(\.displayName).joined(separator: " • ")
  }
}
