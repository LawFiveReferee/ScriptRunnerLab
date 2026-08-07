use script "Myriad Tables Lib"

-- Optional UI test. Close the table to complete execution.
return display table with data {{true, "One"}, {false, "Two"}, {true, "Three"}} editable columns {1} with prompt "ScriptRunnerLab Myriad Tables test" with empty selection allowed
