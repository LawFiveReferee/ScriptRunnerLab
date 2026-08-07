-- Expected: Finder Automation permission may be requested; returns the startup disk name when allowed.
tell application "Finder"
  return name of startup disk
end tell
