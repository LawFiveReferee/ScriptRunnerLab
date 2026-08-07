-- Expected: failed at load/compile time because this library intentionally does not exist.
use script "ScriptRunnerLab Missing Library Fixture"
return "This should never execute"
