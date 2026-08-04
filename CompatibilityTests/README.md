# ScriptRunnerLab Compatibility Scripts

These fixtures exercise the current OSAKit/helper path and preserve examples for future applet and handler support.

## Recommended order

1. Run every script in `01-Core`.
2. Run `02-Isolation/DelayForCancellation.applescript` and press **Cancel**.
3. Select a 5-second timeout and run `02-Isolation/InfiniteLoop.applescript`.
4. Run permission and UI scripts individually; macOS prompts and user interaction are expected.
5. Run only the third-party library probes for libraries installed on the Mac.
6. Run the compiled and bundled files in `Artifacts`.

## Expected special results

- `IntentionalRuntimeError.applescript`: structured error number `-2700`.
- `IntentionalSyntaxError.applescript`: status **AppleScript Compile Error**, error number `-2741`, the compiler message, and a source range.
- `MissingApplication.applescript`: missing-application error.
- `MissingLibrary.applescript`: missing-library compile/load error.
- `UserCancellation.applescript`: error number `-128` when Cancel is selected.
- `InfiniteLoop.applescript`: status **Timed Out**; the main app must stay responsive.
- `DelayForCancellation.applescript`: status **Cancelled**; the main app must stay responsive.
- `PersistentProperty.applescript`: currently returns `1` on each isolated execution because every run uses a fresh helper process.

## Artifact variants

- `BasicReturn.scpt`: compiled-script loading.
- `BundleResource.scptd`: script-bundle loading, `path to me`, and bundled resource access.
- `AppletLifecycle.app`: future applet launch/lifecycle testing; `.app` is not supported by the current runner yet.

The third-party probes deliberately fail at load time when their named library is unavailable, quarantined, unsigned, or incompatible with the current architecture.
