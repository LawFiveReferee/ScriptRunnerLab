-- Expected: may require Accessibility permission for ScriptRunnerHelper.
tell application "System Events"
  tell process "Finder"
    return {processName:name, frontmostState:frontmost}
  end tell
end tell
