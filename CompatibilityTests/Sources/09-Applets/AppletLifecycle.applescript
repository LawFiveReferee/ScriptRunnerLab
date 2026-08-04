property idleInterval : 30

-- Expected: this stay-open applet keeps running until Cancel or Timeout terminates it.
on run
  return {eventName:"run", scriptLocation:((path to me) as text)}
end run

on open droppedItems
  return {eventName:"open", itemCount:(count droppedItems)}
end open

on idle
  return idleInterval
end idle

on quit
  continue quit
end quit
