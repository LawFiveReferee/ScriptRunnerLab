# ScriptRunnerLab

A non-sandboxed macOS test host for proving broad AppleScript compatibility before the execution engine is embedded in other applications.

## Current milestone

- Loads original `.applescript`, `.scpt`, and `.scptd` files with OSAKit
- Launches AppleScript `.app` applets with NSWorkspace and supervises their lifecycle through the helper
- Writes a versioned JSON-lines execution log using reusable ScriptRunnerKit models and writer
- Displays AppleScript's built-in progress values in a compact, cancellable progress window
- Preserves the original file URL and script-bundle context
- Runs each request in a separately signed, agent-style Cocoa helper
- Uses one helper process per request for crash and state isolation
- Supports cancellation and configurable timeouts by terminating only the helper
- Shares Codable request/result models and OSAKit execution through `ScriptRunnerKit`
- Shares Codable ordered collection reports and formatting through `ScriptRunnerKit`
- Uses ScriptRunnerKit's configurable isolated helper launcher for timeout, cancellation, and progress transport
- Uses ScriptRunnerKit's shared recursive discovery and sequential collection runner
- Uses ScriptRunnerKit's host-neutral interactive sequence for repeat, advance, quit, and ordered results
- Uses ScriptRunnerService as the shared host API for execution, collections, cancellation, progress, and logging
- Uses ScriptRunnerKit's shared baseline manifest and compatibility-suite assertion runner
- Copies compatibility summaries as shared human-readable text or portable JSON
- Uses ScriptRunnerKit's shared Cocoa helper runtime behind a minimal embedded launcher
- Uses ScriptRunnerKit's reusable capability analyzer for Favorites compatibility tags
- Uses ScriptRunnerKit's reusable security-scoped Favorite script records
- Reports structured AppleScript errors, source ranges, raw results, duration, UTI, and architecture
- Displays results as AE Print or AppleScript source
- Opens scripts in the user's default editor
- Keeps persistent favorite scripts with source-derived compatibility coverage tags
- Runs unattended compatibility fixtures sequentially with exact result and structured-error assertions
- Lists interactive, permission-sensitive, and optional third-party tests separately with reasons
- Provides Finder and editor actions for the selected script

## Run

Open the project in Bitrig or Xcode, build `ScriptRunnerLab`, choose a script, and select **Run**.

The app is intentionally not sandboxed. macOS privacy controls still apply, so scripts that automate other applications can trigger Automation permission prompts.

Other macOS applications can adopt the same engine through [the ScriptRunnerKit embedding guide](Documentation/EmbeddingScriptRunnerKit.md).

## AppleScript commands

ScriptRunnerLab includes an SDEF dictionary and accepts recursive directory execution requests:

```applescript
tell application "Script Runner Lab"
  execute scripts automatically in (POSIX file "/path/to/scripts")
  execute scripts interactively in (POSIX file "/path/to/scripts")
end tell
```

Automatic execution runs every supported script in sorted order and returns a combined report with each result following its relative script name. Interactive execution shows each result and the next script name, with Run Again, Run Next or Finish, and Quit controls. Interactive requests return after acceptance; automatic requests return their report after execution finishes. Execution remains isolated and is recorded in the shared log.

## Compatibility scripts

ScriptRunnerKit's packaged `CompatibilityTests` resources contain ordered AppleScript fixtures for unattended core checks, cancellation and timeout, Automation and Accessibility permissions, Standard Additions, AppleScriptObjC, third-party libraries, bundled resources, persistent properties, handler behavior, and applet lifecycle support. Compiled `.scpt`, bundled `.scptd`, and applet `.app` variants are included and distributed inside the app as its default Scripts folder. The app's automatic suite runs safe, deterministic tests one at a time and checks exact return values or structured error details. Machine-dependent results use explicit constraints. Interactive, permission-sensitive, intentionally hanging, and optional third-party tests remain visible as manual or optional tests with an explanation.

## Execution log

Every execution attempt is appended to `~/Library/Application Support/ScriptRunnerLab/ScriptExecutionLog.jsonl`. Each line is an independent `ScriptExecutionLogEntry` JSON object containing schema version, host, script, environment, engine, timing, result, and structured error data. Other applications can use `ScriptExecutionLogEntry` and `ScriptExecutionLogWriter` from ScriptRunnerKit with a host-selected log URL.

## Progress presentation

ScriptRunnerKit publishes `ScriptProgressSnapshot` values and provides `ScriptProgressPanelController`. Hosts may present its small progress panel as an attached child window or as an independent floating window; ScriptRunnerLab uses the floating mode intended for UpDock-style presentation.

OSAKit does not publicly expose AppleScript's four built-in progress values to host applications. For scripts whose readable source contains line-oriented `set progress … to …` statements, ScriptRunnerKit compiles an instrumented execution context with the original URL retained. Scripts without those statements continue through the unchanged original-file execution path. Run-only scripts and progress setters embedded inside another statement cannot currently use the custom panel.

## Next milestone

Add a reusable Favorites collection store so hosts can share persistence, refresh, and stale-bookmark handling.

## Scope

This prototype is for direct distribution outside the Mac App Store. It cannot bypass missing libraries, Automation or Accessibility denial, architecture mismatches, code-signing failures, quarantine, or hardened-runtime restrictions in third-party native frameworks.
