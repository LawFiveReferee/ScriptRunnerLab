-- Expected currently: 1 on each run because each request starts a fresh helper process.
property runCount : 0
set runCount to runCount + 1
return runCount
