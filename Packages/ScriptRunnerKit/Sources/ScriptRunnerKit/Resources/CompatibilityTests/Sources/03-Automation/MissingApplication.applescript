-- Expected: failed because this bundle identifier does not exist.
tell application id "org.scriptrunnerlab.missing-application"
  launch
end tell
