use scripting additions

-- Expected: select Cancel and verify structured error number -128.
display dialog "Select Cancel to test user cancellation." buttons {"Cancel", "Continue"} default button "Continue" cancel button "Cancel"
return "Continue selected"
