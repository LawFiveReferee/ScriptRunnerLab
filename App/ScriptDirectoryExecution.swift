import Foundation
import ScriptRunnerKit

enum ScriptDirectoryExecutionMode: String, Sendable {
  case automatically
  case interactively
}

struct ScriptedInteractivePrompt: Identifiable {
  var id = UUID()
  var scriptName: String
  var resultText: String
  var nextScriptName: String?
}
