import ScriptRunnerKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
  @State private var runner = ScriptRunnerModel.shared
  @State private var isShowingImporter = false
  @State private var importerPurpose = ImporterPurpose.script
  @State private var isDropTargeted = false
  @State private var progressPanel = ScriptProgressPanelController()
  @State private var automaticTestsExpanded = true
  @State private var deferredTestsExpanded = false
  @AppStorage("resultDisplayMode") private var resultDisplayMode = ResultDisplayMode.aePrint
  @AppStorage("executionTimeout") private var executionTimeout = ExecutionTimeout.thirtySeconds

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header
          dropZone
          favoritesCard
          compatibilitySuiteCard
          scriptCard
          executionCard
          diagnosticsCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
      }
      .navigationTitle("Script Runner Lab")
      .navigationSubtitle(versionBuildText)
      .toolbar {
        ToolbarItemGroup {
          scriptsFolderMenu
          Button("Choose Script", systemImage: "doc.badge.plus") {
            presentImporter(for: .script)
          }
          .disabled(runner.isRunning)
          Button(
            runner.isRunning ? "Cancel" : "Run",
            systemImage: runner.isRunning ? "stop.fill" : "play.fill"
          ) {
            runOrCancel()
          }
          .disabled(!runner.isRunning && !runner.canRun)
        }
      }
      .fileImporter(
        isPresented: $isShowingImporter,
        allowedContentTypes: importerPurpose.allowedContentTypes,
        allowsMultipleSelection: false
      ) { result in
        switch importerPurpose {
        case .script:
          runner.receiveSelection(result)
        case .scriptsFolder:
          runner.receiveFolderSelection(result)
        case .favoriteRepair(let id):
          runner.receiveFavoriteRepairSelection(result, favoriteID: id)
        }
      }
      .onChange(of: runner.scriptProgress) { _, progress in
        if let progress {
          progressPanel.present(
            progress,
            mode: .floating,
            onCancel: runner.cancel
          )
        }
      }
      .onChange(of: runner.isRunning) { _, isRunning in
        if !isRunning {
          progressPanel.dismiss()
        }
      }
      .sheet(item: $runner.scriptedInteractivePrompt) { prompt in
        scriptedInteractiveResultSheet(prompt)
      }
      .alert(
        "Favorite Needs Repair",
        isPresented: Binding(
          get: { runner.favoriteRepairRequest != nil },
          set: { isPresented in
            if !isPresented {
              runner.favoriteRepairRequest = nil
            }
          }
        ),
        presenting: runner.favoriteRepairRequest
      ) { request in
        Button("Locate Script…") {
          runner.favoriteRepairRequest = nil
          presentImporter(for: .favoriteRepair(request.favoriteID))
        }
        Button("Cancel", role: .cancel) {
          runner.favoriteRepairRequest = nil
        }
      } message: { request in
        Text("“\(request.displayName)” could not be opened. Locate the moved script to preserve this Favorite entry.\n\n\(request.reason)")
      }
    }
  }

  private func scriptedInteractiveResultSheet(_ prompt: ScriptedInteractivePrompt) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(prompt.scriptName)
        .font(.headline)
      Text(prompt.resultText)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
      Divider()
      LabeledContent("Next") {
        Text(prompt.nextScriptName ?? "End of collection")
      }
      HStack {
        Button("Quit", role: .cancel) {
          runner.quitScriptedInteractiveRun()
        }
        Spacer()
        Button("Run Again", systemImage: "arrow.clockwise") {
          runner.repeatScriptedInteractiveScript()
        }
        Button(prompt.nextScriptName == nil ? "Finish" : "Run Next", systemImage: "play.fill") {
          runner.advanceScriptedInteractiveRun()
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(width: 520)
  }

  private var dropZone: some View {
    VStack(spacing: 8) {
      Image(systemName: "square.and.arrow.down")
        .font(.title2)
        .foregroundStyle(isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
      Text("Drop a script here")
        .font(.headline)
      Text("AppleScript source, compiled scripts, script bundles, and applets")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 92)
    .background(
      isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear,
      in: RoundedRectangle(cornerRadius: 12)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.45),
          style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [7, 5])
        )
    }
    .dropDestination(for: URL.self) { urls, _ in
      runner.receiveDroppedURLs(urls)
    } isTargeted: { isTargeted in
      withAnimation(.snappy) {
        isDropTargeted = isTargeted
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Drop a script to select it")
  }

  private var scriptsFolderMenu: some View {
    Menu {
      Button("Reveal in Finder", systemImage: "folder") {
        runner.revealScriptsFolder()
      }
      Button("Choose Scripts Folder…", systemImage: "folder.badge.plus") {
        presentImporter(for: .scriptsFolder)
      }
      Button("Refresh Scripts", systemImage: "arrow.clockwise") {
        runner.refreshScriptsFolder()
      }
      Button("Use Compatibility Tests", systemImage: "arrow.uturn.backward") {
        runner.useBundledCompatibilityTests()
      }

      Divider()
      if runner.scriptsFolderEntries.isEmpty {
        Text("No scripts found")
      } else {
        ForEach(runner.scriptsFolderEntries) { entry in
          Button {
            runner.selectFolderScript(entry)
          } label: {
            if runner.hasExecuted(entry) {
              Label(entry.relativePath, systemImage: "checkmark")
            } else {
              Text(entry.relativePath)
            }
          }
          .accessibilityLabel(
            runner.hasExecuted(entry) ? "Executed: \(entry.relativePath)" : entry.relativePath
          )
          .disabled(runner.isRunning)
        }
      }
    } label: {
      Label(runner.scriptsFolderDisplayName, systemImage: "folder")
    }
    .labelStyle(.iconOnly)
    .help("Scripts in \(runner.scriptsFolderDisplayName)")
    .accessibilityLabel("Scripts folder: \(runner.scriptsFolderDisplayName)")
    .contextMenu {
      Button("Reveal in Finder", systemImage: "folder") {
        runner.revealScriptsFolder()
      }
      Button("Choose Scripts Folder…", systemImage: "folder.badge.plus") {
        presentImporter(for: .scriptsFolder)
      }
      Button("Refresh Scripts", systemImage: "arrow.clockwise") {
        runner.refreshScriptsFolder()
      }
      Button("Use Compatibility Tests", systemImage: "arrow.uturn.backward") {
        runner.useBundledCompatibilityTests()
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Native AppleScript execution", systemImage: "applescript")
        .font(.title2.bold())
      Text("Runs scripts with OSAKit and launches AppleScript applets with NSWorkspace while preserving their original bundle context.")
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
          Button(
            runner.isRunning ? "Cancel" : "Run",
            systemImage: runner.isRunning ? "stop.fill" : "play.fill"
          ) {
            runOrCancel()
          }
          .buttonStyle(.borderedProminent)
          .tint(runner.isRunning ? .red : .accentColor)
          .disabled(!runner.isRunning && !runner.canRun)
          if runner.isRunning {
            ProgressView()
              .controlSize(.small)
          }
          statusLabel
          Spacer()
          Text(runner.durationText)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }

        Picker("Timeout", selection: $executionTimeout) {
          ForEach(ExecutionTimeout.allCases) { timeout in
            Text(timeout.displayName).tag(timeout)
          }
        }
        .pickerStyle(.menu)
        .disabled(runner.isRunning)

        Picker("Result format", selection: $resultDisplayMode) {
          ForEach(ResultDisplayMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)

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

  private var compatibilitySuiteCard: some View {
    GroupBox("Compatibility Suite") {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Button(
            runner.isRunningCompatibilitySuite ? "Stop Suite" : "Run Automatic Tests",
            systemImage: runner.isRunningCompatibilitySuite ? "stop.fill" : "play.fill"
          ) {
            if runner.isRunningCompatibilitySuite {
              runner.cancel()
            } else {
              runner.runAutomaticCompatibilitySuite()
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(runner.isRunningCompatibilitySuite ? .red : .accentColor)
          .disabled(runner.isRunning && !runner.isRunningCompatibilitySuite)

          if runner.isRunningCompatibilitySuite {
            ProgressView()
              .controlSize(.small)
          }

          Text(compatibilitySummaryLabel)
            .foregroundStyle(.secondary)
            .monospacedDigit()

          Spacer()

          Button("Copy Summary", systemImage: "document.on.document") {
            runner.copyCompatibilitySummary()
          }
          .disabled(!runner.hasCompatibilityResults)

          Button("Copy JSON", systemImage: "curlybraces") {
            runner.copyCompatibilitySummaryJSON()
          }
          .disabled(!runner.hasCompatibilityResults)
        }

        if let currentTestName = runner.currentCompatibilityTestName {
          LabeledContent("Running") {
            Text(currentTestName)
              .lineLimit(1)
          }
        }

        ProgressView(
          value: Double(runner.completedCompatibilityTestCount),
          total: Double(runner.automaticCompatibilityTests.count)
        )
        .accessibilityLabel("Compatibility suite progress")
        .accessibilityValue(compatibilitySummaryLabel)

        DisclosureGroup(
          "Automatic Tests (\(runner.automaticCompatibilityTests.count))",
          isExpanded: $automaticTestsExpanded
        ) {
          VStack(spacing: 0) {
            ForEach(Array(runner.automaticCompatibilityTests.enumerated()), id: \.element.id) { index, test in
              automaticCompatibilityRow(test)
              if index < runner.automaticCompatibilityTests.count - 1 {
                Divider()
              }
            }
          }
          .padding(.top, 6)
        }

        DisclosureGroup(
          "Manual & Optional (\(runner.deferredCompatibilityTests.count))",
          isExpanded: $deferredTestsExpanded
        ) {
          VStack(alignment: .leading, spacing: 0) {
            Text("Double-click a test or use Run. The selected Execution timeout applies.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.vertical, 7)

            Divider()

            ForEach(Array(runner.deferredCompatibilityTests.enumerated()), id: \.element.id) { index, test in
              deferredCompatibilityRow(test)
              if index < runner.deferredCompatibilityTests.count - 1 {
                Divider()
              }
            }
          }
          .padding(.top, 6)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 8)
    }
  }

  private var diagnosticsCard: some View {
    GroupBox("Diagnostics") {
      VStack(alignment: .leading, spacing: 10) {
        Text(runner.diagnosticsText)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button("Copy Diagnostics", systemImage: "document.on.document") {
          runner.copyDiagnostics()
        }
      }
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

  private var compatibilitySummaryLabel: String {
    if !runner.hasCompatibilityResults && !runner.isRunningCompatibilitySuite {
      return "Not run • \(runner.compatibilityContentAssertionCount) assertions"
    }
    return "\(runner.completedCompatibilityTestCount) of \(runner.automaticCompatibilityTests.count) • \(runner.passedCompatibilityTestCount) passed • \(runner.failedCompatibilityTestCount) failed"
  }

  private func automaticCompatibilityRow(_ test: CompatibilityTestDefinition) -> some View {
    let testResult = runner.compatibilityResults[test.id] ?? .pending
    return HStack(spacing: 10) {
      Image(systemName: compatibilitySymbol(for: testResult.state))
        .foregroundStyle(compatibilityColor(for: testResult.state))
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(test.displayName)
        Text(test.relativePath)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(testResult.state == .pending ? test.expectedOutcome?.displayName ?? "" : testResult.state.displayName)
          .font(.caption)
          .foregroundStyle(compatibilityColor(for: testResult.state))
        if let duration = testResult.duration {
          Text(duration.formatted(.number.precision(.fractionLength(2))) + " s")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 7)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(test.displayName), \(testResult.state.displayName)")
  }

  private func deferredCompatibilityRow(_ test: CompatibilityTestDefinition) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: runner.hasExecuted(test) ? "checkmark.circle.fill" : "hand.raised")
        .foregroundStyle(runner.hasExecuted(test) ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(test.displayName)
          Text(test.disposition.displayName)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(test.disposition.reason ?? "")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()

      Button("Run", systemImage: "play.fill") {
        runDeferredCompatibilityTest(test)
      }
      .disabled(runner.isRunning)
    }
    .padding(.vertical, 7)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
      runDeferredCompatibilityTest(test)
    }
    .help("Double-click to run \(test.displayName)")
  }

  private func runDeferredCompatibilityTest(_ test: CompatibilityTestDefinition) {
    runner.runCompatibilityTest(test, timeout: executionTimeout.seconds)
  }

  private func compatibilitySymbol(for state: CompatibilityTestRunState) -> String {
    switch state {
    case .pending: "circle"
    case .running: "arrow.trianglehead.2.clockwise.rotate.90"
    case .passed: "checkmark.circle.fill"
    case .failed: "xmark.circle.fill"
    case .stopped: "stop.circle.fill"
    }
  }

  private func compatibilityColor(for state: CompatibilityTestRunState) -> Color {
    switch state {
    case .pending: .secondary
    case .running: .accentColor
    case .passed: .green
    case .failed: .red
    case .stopped: .orange
    }
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

  private var versionBuildText: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    return "Version \(version) • Build \(build)"
  }

  private func runOrCancel() {
    if runner.isRunning {
      runner.cancel()
    } else {
      runner.run(timeout: executionTimeout.seconds)
    }
  }

  private func presentImporter(for purpose: ImporterPurpose) {
    importerPurpose = purpose
    isShowingImporter = true
  }
}

private enum ImporterPurpose {
  case script
  case scriptsFolder
  case favoriteRepair(UUID)

  var allowedContentTypes: [UTType] {
    switch self {
    case .script, .favoriteRepair: [.item]
    case .scriptsFolder: [.folder]
    }
  }
}
