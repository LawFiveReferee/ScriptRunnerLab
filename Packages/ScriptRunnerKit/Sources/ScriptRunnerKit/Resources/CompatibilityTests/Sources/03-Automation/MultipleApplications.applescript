-- Expected: Automation permission may be requested for Finder and System Events.
tell application "Finder" to set finderName to name
tell application "System Events" to set systemEventsName to name
return {finderName, systemEventsName}
