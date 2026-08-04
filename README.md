# ScriptRunnerLab

A non-sandboxed macOS test host for proving broad AppleScript compatibility before the execution engine is embedded in other applications.

## Current milestone

- Loads original `.applescript`, `.scpt`, and `.scptd` files with OSAKit
- Preserves the original file URL and script-bundle context
- Runs in a Cocoa application with AppKit and a main run loop
- Reports structured AppleScript errors, source ranges, raw results, duration, UTI, and architecture
- Provides Finder and Script Editor actions for the selected script

## Run

Open the project in Bitrig or Xcode, build `ScriptRunnerLab`, choose a script, and select **Run**.

The app is intentionally not sandboxed. macOS privacy controls still apply, so scripts that automate other applications can trigger Automation permission prompts.

## Next milestone

Move execution into a separately signed, agent-style Cocoa helper. The host will send one structured request per helper process, allowing cancellation and timeouts by terminating only that helper. The shared models and OSAKit execution code will then move into `ScriptRunnerKit`.

## Scope

This prototype is for direct distribution outside the Mac App Store. It cannot bypass missing libraries, Automation or Accessibility denial, architecture mismatches, code-signing failures, quarantine, or hardened-runtime restrictions in third-party native frameworks.
