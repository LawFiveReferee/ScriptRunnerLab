# Embedding ScriptRunnerKit

ScriptRunnerKit is the reusable execution layer. A host application embeds a separately signed copy of ScriptRunnerHelper and creates one `ScriptRunnerService` for the lifetime of the host process.

## Host target

1. Add `Packages/ScriptRunnerKit` as a local Swift package dependency and link the `ScriptRunnerKit` product.
2. Add a Cocoa application target with a minimal launcher and link that target to ScriptRunnerKit:

   ```swift
   import ScriptRunnerKit

   @main
   enum ScriptRunnerHelperMain {
     @MainActor
     static func main() {
       ScriptRunnerHelperRuntime.run()
     }
   }
   ```
3. Set the helper's `LSUIElement` value to `true` so it runs as an agent without a Dock icon.
4. Embed and sign the helper application in the host at `Contents/Helpers/ScriptRunnerHelper.app`.
5. Keep the host and helper non-sandboxed for the compatibility goals of this project.

ScriptRunnerLab's target definitions in `Project.json` are the reference configuration for the package dependency, helper target, copy destination, and embedded signing.

## Service setup

Create the service on the main actor and retain it. Host metadata is written into every JSON-lines execution-log entry.

```swift
import ScriptRunnerKit

@MainActor
func makeScriptRunnerService() -> ScriptRunnerService {
  let bundle = Bundle.main
  let helperURL = bundle.bundleURL.appending(
    path: "Contents/Helpers/ScriptRunnerHelper.app/Contents/MacOS/ScriptRunnerHelper"
  )
  let applicationSupportURL = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
  ).first ?? FileManager.default.temporaryDirectory
  let logURL = applicationSupportURL
    .appending(path: "UpDock", directoryHint: .isDirectory)
    .appending(path: "ScriptExecutionLog.jsonl")

  return ScriptRunnerService(
    configuration: .current(
      helperExecutableURL: helperURL,
      workingDirectoryName: "UpDock",
      logURL: logURL,
      bundle: bundle,
      displayNameFallback: "UpDock"
    )
  )
}
```

## Single execution

`execute(scriptURL:timeout:progressHandler:)` accepts `.applescript`, `.scpt`, `.scptd`, and AppleScript `.app` URLs. It returns a structured result for success, compile errors, execution errors, timeout, or cancellation and records the attempt when a log URL is configured.

```swift
let result = await scriptRunnerService.execute(
  scriptURL: scriptURL,
  timeout: 30
) { progress in
  currentProgress = progress
}
```

Call `scriptRunnerService.cancel()` to terminate the current isolated helper and its applet, if any.

Use `ScriptCapability.detect(in:)` to build host-neutral compatibility tags for source scripts, compiled scripts, bundles, and applets. The Codable results preserve named framework and script-library details and can be stored with a host's Favorites metadata.

`FavoriteScript(descriptor:)` creates a security-scoped bookmark and stores the analyzed capabilities. Hosts can encode the record directly and call `resolvedURL()` on launch. If bookmark resolution reports stale data, ask the user to reselect the script and replace the record with `FavoriteScript(id:replacing:)`.

For a complete collection, create `FavoriteScriptStore(defaults:storageKey:)`. The observable store loads the existing JSON representation, prevents duplicates, keeps entries sorted, and persists additions and removals. `resolveAndRefresh(id:)` resolves access and refreshes the bookmark, path, type, and capability metadata without changing the entry ID. If resolution fails, use `replace(id:with:)` after the user reselects the moved script.

## Collections

Use `executeAutomatically` for recursive sorted execution. Use `executeInteractively` when the host wants to present each result and return `.runAgain`, `.runNext`, or `.quit` from its own UI. Both APIs use one helper process per script and write every result to the configured log.

The interactive action provider is host-neutral. UpDock can therefore display its result prompt as an independent frontmost window, while another host can use an attached sheet, without changing ScriptRunnerKit.

## AppleScript commands

An AppleScriptable host adds its own commands to its SDEF and forwards them to the two collection methods. `App/ExecuteScriptsCommand.swift` and `App/ScriptRunnerLab.sdef` are the reference command bridge. The scripting definition remains host-owned so application names and terminology do not leak into ScriptRunnerKit.

## Compatibility suite

The package embeds the complete baseline fixture set. Pass `CompatibilityTestResources.rootURL` to `executeCompatibilitySuite`; no separate resource-copy phase is required in the host. The default manifest supplies the same automatic tests and assertions used by ScriptRunnerLab. Start, progress, and completion callbacks allow the host to build its own live test interface; the returned report contains ordered per-test results and completion state.

Manual and optional definitions are available through `CompatibilityTestDefinition.deferredTests`. Hosts decide how and when to present those permission-sensitive, interactive, or third-party tests.

Create a `CompatibilitySuiteSummary` from the host configuration, manifest, and accumulated results to export the same detailed report as either `text` or versioned JSON from `jsonData()`.

## Distribution checks

Before distributing a host, verify the outer app and embedded helper with `codesign --verify --deep --strict`, then test Developer ID signing, hardened runtime, notarization, quarantine, Automation permission prompts, and third-party framework architectures on a clean Mac.
