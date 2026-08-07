import ScriptRunnerKit

@main
enum ScriptRunnerHelperMain {
  @MainActor
  static func main() {
    ScriptRunnerHelperRuntime.run()
  }
}
