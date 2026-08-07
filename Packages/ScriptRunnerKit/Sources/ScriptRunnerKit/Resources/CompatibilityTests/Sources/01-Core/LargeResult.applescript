-- Expected: a 1,000-item list without truncation or a helper failure.
set outputValues to {}
repeat with itemNumber from 1 to 1000
  set end of outputValues to itemNumber
end repeat
return outputValues
