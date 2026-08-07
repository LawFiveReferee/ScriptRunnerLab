# ScriptRunnerLab Changelog

## Current development build

- Version: 1.0
- Build: 25
- Date: 2026-08-07
- Repository folder: `/Users/edstockly/Library/Bitrig/Users/3779/Projects/72da40c7-4c80-4ecd-8c37-98a66a39f4b4`
- Xcode project: `ScriptRunnerLab.xcodeproj`
- Baseline release: Not yet designated

### Build 25

- Added a versioned, Codable compatibility-suite summary model to ScriptRunnerKit.
- Shared summaries include host/build identity, environment, timing, expectations, observations, deferred tests, and log location.
- Added shared human-readable formatting and stable ISO 8601 JSON export.
- ScriptRunnerLab's Copy Summary now uses the package formatter and the UI adds Copy JSON.
- Added JSON round-trip and formatted-report regression coverage.

## Build history

### Version 1.0, build 24

- Moved the baseline compatibility manifest, expectations, assertions, and result models into ScriptRunnerKit.
- Added reusable sequential compatibility-suite execution to ScriptRunnerService with live test and progress callbacks.
- Preserved the established baseline of 20 automatic tests and 26 content assertions.
- Migrated ScriptRunnerLab's compatibility window to the shared suite runner while retaining its existing live UI and summaries.
- Added package regression coverage for manifest integrity, ordered results, passing assertions, and assertion failures.

### Version 1.0, build 23

- Added ScriptRunnerService as the supported host entry point for isolated execution, collections, cancellation, progress, and JSON-lines logging.
- Added host configuration that records the embedding application's identity and current execution environment.
- Migrated ScriptRunnerLab's single runs, compatibility suite, and collection runs to the same service intended for UpDock.
- Added an embedding guide covering the package, Cocoa helper target, signing, service setup, collections, and AppleScript commands.
- Added service regression coverage for structured execution and host-specific log output.

### Version 1.0, build 22

- Added reusable interactive collection sequencing to ScriptRunnerKit.
- Hosts provide their own result presentation while shared code manages Run Again, Run Next, Finish, and Quit decisions.
- Interactive reports preserve every execution result, including repeated runs, in execution order.
- Collection cancellation now targets the current isolated helper without discarding the interactive session.
- Added package regression coverage for repeat, advance, completion, and ordered interactive results.

### Version 1.0, build 21

- Added reusable recursive script discovery and automatic collection execution to ScriptRunnerKit.
- Shared discovery filters supported scripts, treats script packages as leaves, and returns deterministic relative-path order.
- ScriptRunnerLab's folder menus and automatic AppleScript command now use the shared package implementation.
- Added package regression coverage for recursive ordering, script-type detection, and unsupported-file filtering.

### Version 1.0, build 20

- Moved isolated helper-process launching into reusable ScriptRunnerKit.
- Hosts now provide their embedded helper executable URL and temporary-work namespace.
- Shared execution includes timeout, cancellation, forced termination, progress transport, and structured results.
- Added a package regression test for missing-helper validation.

### Version 1.0, build 19

- Added reusable Codable collection-report, entry-result, and execution-mode models to ScriptRunnerKit.
- ScriptRunnerLab now formats and returns automatic collection results through the shared package model.
- Added package regression tests for result ordering, success/error formatting, and JSON round trips.

### Version 1.0, build 18

- Automatic AppleScript collection commands now return and display every script result.
- Each result follows its relative script name and includes structured failure details when applicable.
- Automatic Apple events suspend and resume asynchronously so the app stays responsive during execution.

### Version 1.0, build 17

- Made ScriptRunnerLab AppleScriptable with a bundled SDEF scripting dictionary.
- Added automatic and interactive recursive script-collection commands.
- Added an interactive result sheet with Run Again, Run Next or Finish, and Quit.
- Scripted collection runs use the selected timeout, isolated helper, execution UI, and shared log.

### Version 1.0, build 16

- Added inline Run buttons and double-click execution for Manual and Optional compatibility tests.
- Manual runs use the selected Execution timeout and the normal isolated helper and logging path.
- Added per-launch completion checkmarks for manually executed compatibility tests.

### Version 1.0, build 15

- Corrected compatibility-suite start-time recording in copied baseline summaries.

### Version 1.0, build 14

- Added exact content assertions for deterministic automatic compatibility tests.
- Added structured validation of expected error status, number, message, and source range.
- Added dynamic constraints for machine-dependent values such as AppKit screen count and bundle paths.
- Expanded copied compatibility summaries with environment, timing, expectations, observations, and duration.

### Version 1.0, build 13

- Added a sequential unattended compatibility suite with one isolated helper process per test.
- Added expected success and expected-error validation with live per-test results.
- Added Stop, progress, manual and optional test classifications, and a copyable summary.
- Suite executions use the shared JSON-lines execution log.

### Version 1.0, build 12

- Added reusable ScriptRunnerKit snapshots for AppleScript's built-in progress properties.
- Added compact attached or floating progress-window presentation with cancellation.
- Added live helper-to-host progress transport and a built-in progress compatibility test.
- Added Built-in Progress detection to Favorites compatibility tags.

### Version 1.0, build 11

- Moved Scripts-folder commands above the script list and added Reveal in Finder.

### Version 1.0, build 10

- Added script name and full path at the top of Diagnostics.
- Added status, duration, and final return value or error at the end of Diagnostics.
- Added Copy Diagnostics.
- Added a reusable, versioned ScriptRunnerKit JSON-lines execution log for ScriptRunnerLab, UpDock, and other hosts.

### Version 1.0, build 9

- Added structural detection of AppleScript `.app` applets while rejecting ordinary application bundles.
- Added supervised applet launching through NSWorkspace in ScriptRunnerHelper.
- Applet cancellation and timeout now terminate both the helper and the launched applet process.
- Added short-lived and stay-open applet compatibility fixtures and detection regression tests.

### Version 1.0, build 8

- Moved version/build metadata into the native macOS navigation subtitle for small secondary title text.

### Version 1.0, build 7

- Removed the duplicate centered toolbar title and combined version/build with the normal window title.
- Consolidated script and folder selection into one file importer to restore reliable Choose Script presentation.

### Version 1.0, build 6

- Added live recursive monitoring of the selected Scripts folder.
- Added an explicit Refresh Scripts command to the folder menu and its context menu.

### Version 1.0, build 5

- Moved Timeout above Result Format so the format control sits directly above the result display.

### Version 1.0, build 4

- Reordered the Execution header with Run/Cancel at the leading edge, followed by activity and status, with duration trailing.

### Version 1.0, build 3

- Added per-launch checkmarks beside Scripts-folder items that have been run.

### Version 1.0, build 2

- Added isolated helper-process execution, cancellation, and configurable timeouts.
- Added Favorites with compatibility-capability detection.
- Added AE Print and Source result modes.
- Added a bundled compatibility-test collection and persistent Scripts folder menu.
- Added script drag and drop.
- Open in Editor now uses the user’s default AppleScript editor role.
- Added explicit AppleScript compilation with structured compile-error reporting.
- Added version/build display and an Execution-panel Run/Cancel control.

### Version 1.0, build 1

- Initial native SwiftUI and OSAKit milestone.
- Supported `.applescript`, `.scpt`, and `.scptd` selection and execution.
- Added structured result, error, and diagnostic display.

## Baseline releases

No baseline release has been designated. When releases begin, each baseline entry will record its version and build, date, Git tag and commit, Xcode project path, signing/notarization status, and distributed artifact details. This section can be adjusted to match UpDock’s exact baseline format when an example is available.
