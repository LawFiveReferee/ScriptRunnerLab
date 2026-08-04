import SwiftUI

extension ScriptExecutionStatus {
  var symbolName: String {
    switch self {
    case .ready: "circle.dotted"
    case .running: "play.fill"
    case .completed: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    }
  }

  var color: Color {
    switch self {
    case .ready: .secondary
    case .running: .accentColor
    case .completed: .green
    case .failed: .red
    }
  }
}
