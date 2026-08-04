property idleInterval : 30

-- Current runner expectation: .app is unsupported. Future applet tests use these lifecycle handlers.
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
