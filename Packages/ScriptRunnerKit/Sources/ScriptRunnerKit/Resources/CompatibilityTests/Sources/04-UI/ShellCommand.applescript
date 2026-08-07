use scripting additions

-- Expected: scripting additions and command output both work.
return do shell script "/usr/bin/printf 'Shell command OK'"
