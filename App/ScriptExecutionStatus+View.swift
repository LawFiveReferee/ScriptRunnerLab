import ScriptRunnerKit
import SwiftUI

extension ScriptExecutionStatus {
  var symbolName: String {
    switch self {
    case .ready: "circle.dotted"
    case .running: "play.fill"
    case .completed: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    case .cancelled: "stop.fill"
    case .timedOut: "clock.badge.exclamationmark.fill"
    }
  }

  var color: Color {
    switch self {
    case .ready: .secondary
    case .running: .accentColor
    case .completed: .green
    case .failed: .red
    case .cancelled: .orange
    case .timedOut: .orange
    }
  }
}
