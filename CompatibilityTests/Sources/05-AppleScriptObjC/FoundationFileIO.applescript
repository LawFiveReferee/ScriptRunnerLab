use framework "Foundation"
use scripting additions

-- Expected: Foundation can create and remove a temporary file; returns its contents.
set temporaryDirectory to current application's NSTemporaryDirectory()
set filePath to temporaryDirectory's stringByAppendingPathComponent:("ScriptRunnerLab-" & (random number from 100000 to 999999) & ".txt")
set testText to current application's NSString's stringWithString:"Foundation file IO OK"
set writeResult to testText's writeToFile:filePath atomically:true encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)
if writeResult as boolean is false then error "Foundation could not write the temporary file."
set readText to current application's NSString's stringWithContentsOfFile:filePath encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)
current application's NSFileManager's defaultManager()'s removeItemAtPath:filePath |error|:(missing value)
return readText as text
