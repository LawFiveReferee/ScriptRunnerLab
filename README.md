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
- Reports structured AppleScript errors, source ranges, raw results, duration, UTI, and architecture
- Displays results as AE Print or AppleScript source
- Opens scripts in the user's default editor
- Keeps persistent favorite scripts with source-derived compatibility coverage tags
- Provides Finder and editor actions for the selected script

## Run

Open the project in Bitrig or Xcode, build `ScriptRunnerLab`, choose a script, and select **Run**.

The app is intentionally not sandboxed. macOS privacy controls still apply, so scripts that automate other applications can trigger Automation permission prompts.

## Compatibility scripts

`CompatibilityTests` contains ordered AppleScript fixtures for unattended core checks, cancellation and timeout, Automation and Accessibility permissions, Standard Additions, AppleScriptObjC, third-party libraries, bundled resources, persistent properties, handler behavior, and applet lifecycle support. Compiled `.scpt`, bundled `.scptd`, and applet `.app` variants are included and distributed inside the app as its default Scripts folder.

## Execution log

Every execution attempt is appended to `~/Library/Application Support/ScriptRunnerLab/ScriptExecutionLog.jsonl`. Each line is an independent `ScriptExecutionLogEntry` JSON object containing schema version, host, script, environment, engine, timing, result, and structured error data. Other applications can use `ScriptExecutionLogEntry` and `ScriptExecutionLogWriter` from ScriptRunnerKit with a host-selected log URL.

## Progress presentation

ScriptRunnerKit publishes `ScriptProgressSnapshot` values and provides `ScriptProgressPanelController`. Hosts may present its small progress panel as an attached child window or as an independent floating window; ScriptRunnerLab uses the floating mode intended for UpDock-style presentation.

OSAKit does not publicly expose AppleScript's four built-in progress values to host applications. For scripts whose readable source contains line-oriented `set progress … to …` statements, ScriptRunnerKit compiles an instrumented execution context with the original URL retained. Scripts without those statements continue through the unchanged original-file execution path. Run-only scripts and progress setters embedded inside another statement cannot currently use the custom panel.

## Next milestone

Automate the unattended compatibility fixtures while retaining manual tests for permissions and interactive UI.

## Scope

This prototype is for direct distribution outside the Mac App Store. It cannot bypass missing libraries, Automation or Accessibility denial, architecture mismatches, code-signing failures, quarantine, or hardened-runtime restrictions in third-party native frameworks.
