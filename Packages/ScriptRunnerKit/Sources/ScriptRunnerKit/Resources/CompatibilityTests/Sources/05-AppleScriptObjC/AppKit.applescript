use framework "AppKit"

-- Expected: a positive screen count through AppKit.
set availableScreens to current application's NSScreen's screens()
return (availableScreens's |count|()) as integer
