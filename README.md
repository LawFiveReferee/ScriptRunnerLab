# ScriptRunnerLab

A non-sandboxed macOS test host for proving broad AppleScript compatibility before the execution engine is embedded in other applications.

## Current milestone

- Loads original `.applescript`, `.scpt`, and `.scptd` files with OSAKit
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

`CompatibilityTests` contains ordered AppleScript fixtures for unattended core checks, cancellation and timeout, Automation and Accessibility permissions, Standard Additions, AppleScriptObjC, third-party libraries, bundled resources, persistent properties, handler behavior, and future applet lifecycle support. Compiled `.scpt`, bundled `.scptd`, and applet `.app` variants are included.

## Next milestone

Add AppleScript applet execution and automate the unattended compatibility fixtures while retaining manual tests for permissions and interactive UI.

## Scope

This prototype is for direct distribution outside the Mac App Store. It cannot bypass missing libraries, Automation or Accessibility denial, architecture mismatches, code-signing failures, quarantine, or hardened-runtime restrictions in third-party native frameworks.
