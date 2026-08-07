use scripting additions

-- Expected: a Standard Additions dialog; Continue returns the entered text.
set dialogResult to display dialog "ScriptRunnerLab dialog test" default answer "Hello" buttons {"Cancel", "Continue"} default button "Continue"
return text returned of dialogResult
