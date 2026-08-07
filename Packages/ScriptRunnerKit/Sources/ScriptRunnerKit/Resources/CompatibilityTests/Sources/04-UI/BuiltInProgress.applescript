set progress total steps to 10
set progress completed steps to 0
set progress description to "Testing AppleScript progress"
set progress additional description to "Preparing…"

repeat with stepNumber from 1 to 10
	set progress completed steps to stepNumber
	set progress additional description to "Step " & stepNumber & " of 10"
	delay 1
end repeat

return "Built-in progress completed"
