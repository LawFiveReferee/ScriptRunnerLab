# Embedding ScriptRunnerKit

## Package and helper architecture

Add `https://github.com/LawFiveReferee/ScriptRunnerLab.git` as a Swift package dependency and link the `ScriptRunnerKit` product to both the host and a small Cocoa helper application target. Create one `ScriptRunnerService` on the main actor and retain it for the host process. Every accepted script gets a new helper process; the helper exits when that request finishes.

The candidate API documented here is intended for ScriptRunnerKit 1.1.0. Continue pinning production hosts to 1.0.0 until 1.1.0 is reviewed and tagged.

## Minimal embedded helper

The helper launcher needs only:

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

Its Info.plist must describe an application and set `LSUIElement` to `true`:

```xml
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>LSUIElement</key>
<true/>
```

Embed the helper application at `Contents/Helpers/ScriptRunnerHelper.app`. In Xcode, add the helper as a target dependency and an Embed App Extensions/Copy Files entry whose destination is Wrapper, subpath is `Contents/Helpers`, with Code Sign on Copy enabled. Enable the hardened runtime for release builds of both targets and give each target only the entitlements its behavior requires. Keep the host and helper marketing version and build number synchronized.

ScriptRunnerLab's `Helper/ScriptRunnerHelperMain.swift`, `Helper/Info.plist`, `Project.json`, and Xcode project are a working reference. Before distribution, run `codesign --verify --deep --strict --verbose=2 Host.app` and inspect both targets with `codesign -d --verbose=4`.

## Service setup

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
    .appending(path: "ExampleHost", directoryHint: .isDirectory)
    .appending(path: "ScriptExecutionLog.jsonl")

  return ScriptRunnerService(
    configuration: .current(
      helperExecutableURL: helperURL,
      workingDirectoryName: "ExampleHost-ScriptRunner",
      logURL: logURL,
      bundle: bundle,
      displayNameFallback: "Example Host"
    )
  )
}
```

The default overlap policy is `.rejectNew`. A conflicting single request returns a `.busy` `ScriptExecutionResult`; a conflicting collection throws `ScriptRunnerServiceError.busy`. The accepted request remains the sole owner of cancellation state. Sequential collection execution is unchanged.

## Files and logical script identity

The original API remains available:

```swift
let result = await service.execute(scriptURL: scriptURL, timeout: 30) { progress in
  currentProgress = progress
}
```

For source stored inside a host database or settings model, write an execution copy to a temporary `.applescript` file and supply its logical identity:

```swift
let executionURL = FileManager.default.temporaryDirectory
  .appending(path: UUID().uuidString)
  .appendingPathExtension("applescript")
try Data(source.utf8).write(to: executionURL, options: .atomic)
defer { try? FileManager.default.removeItem(at: executionURL) }

let identity = ScriptExecutionIdentity(
  displayName: commandName,
  originalURL: importedSourceURL
)
let result = await service.execute(
  scriptURL: executionURL,
  identity: identity,
  timeout: 30
) { progress in
  // progress.scriptIdentity contains the same logical identity.
}
```

`originalURL` is optional. When supplied, the logical name and original path/type are used in JSONL metadata instead of the UUID temporary filename. The helper still executes the explicitly supplied `scriptURL`.

Use `ScriptExecutionFailureFormatter` for a reusable detailed failure containing the logical name, elapsed time, status, structured error number and source range, and original error message.

## Progress presentation

A host may own progress UI and consume only `ScriptProgressSnapshot`, or use the package's compact cancellable panel. The default initializer preserves ScriptRunnerLab's existing 360 × 142 “Script Progress” panel.

```swift
import AppKit

let panel = ScriptProgressPanelController(
  configuration: ScriptProgressPanelConfiguration(
    contentSize: NSSize(width: 380, height: 176),
    windowTitle: { identity in identity?.displayName ?? "Script Progress" },
    footer: ScriptProgressPanelFooter(
      icon: NSApp.applicationIconImage,
      text: "Example Host",
      alignment: .trailing
    )
  )
)

panel.present(snapshot, mode: .floating) {
  service.cancel()
}
```

Use `.attached` with a parent window for app-local presentation or `.floating` for an independent frontmost utility panel. Icon, footer, title policy, sizing, and alignment are host configuration; ScriptRunnerKit supplies no host artwork or branding. Cancellation behavior is the same in either mode.

## Collections

`executeAutomatically` discovers supported items recursively and executes them in deterministic relative-path order. `executeInteractively` uses the same ordering but asks the host for `.runAgain`, `.runNext`, or `.quit` after each result. Both preserve every result in their report and use one isolated helper per accepted script. The host owns result windows, command history, AppleScript/SDEF commands, and persistence.

Collection discovery supports:

- `.applescript`: compiled and executed with OSAKit while retaining file context.
- `.scpt`: the original compiled script is executed with OSAKit.
- `.scptd`: the original script bundle is an indivisible discovery item, preserving bundled resources.
- AppleScript `.app`: the applet is an indivisible discovery item and is launched through NSWorkspace under helper supervision.

Directories inside `.scptd` and `.app` packages are never enumerated as separate collection scripts. Unsupported ordinary applications are ignored.

## Favorites, capabilities, and compatibility suite

`ScriptCapability.detect(in:)`, `FavoriteScript`, and `FavoriteScriptStore` provide optional host-neutral metadata and security-scoped bookmark support. The host owns repair prompts and its storage keys.

The package embeds the baseline compatibility fixtures. Pass `CompatibilityTestResources.rootURL` to `executeCompatibilitySuite`. Automatic tests are deterministic; manual and optional definitions remain available through `CompatibilityTestDefinition.deferredTests` for host-controlled permission, UI, timeout, cancellation, and third-party-library testing.

## Distribution cautions

The runner cannot bypass Automation, Accessibility, Full Disk Access, quarantine, signing, library validation, or architecture restrictions. Test Developer ID signing, hardened runtime, notarization, embedded-helper signing, third-party native frameworks, and privacy prompts on a clean Mac before shipping.
