use framework "Foundation"

-- Expected: "SCRIPTRUNNERLAB" using NSString through AppleScriptObjC.
set inputText to current application's NSString's stringWithString:"ScriptRunnerLab"
return (inputText's uppercaseString()) as text
