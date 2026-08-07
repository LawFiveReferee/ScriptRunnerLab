-- Expected now: run handler calls echoValue and returns "Handler OK".
-- Future direct-handler test: invoke echoValue with an explicit argument.
on echoValue(inputValue)
  return inputValue
end echoValue

on run
  return echoValue("Handler OK")
end run
