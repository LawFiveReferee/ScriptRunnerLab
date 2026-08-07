-- Expected: the applet launches, runs, and exits with status Completed.
on run
  return {eventName:"run", scriptLocation:((path to me) as text)}
end run
