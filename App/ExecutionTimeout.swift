import Foundation

enum ExecutionTimeout: Int, CaseIterable, Identifiable {
  case fiveSeconds = 5
  case fifteenSeconds = 15
  case thirtySeconds = 30
  case oneMinute = 60
  case fiveMinutes = 300

  var id: Self { self }
  var seconds: TimeInterval { TimeInterval(rawValue) }

  var displayName: String {
    switch self {
    case .fiveSeconds: "5 seconds"
    case .fifteenSeconds: "15 seconds"
    case .thirtySeconds: "30 seconds"
    case .oneMinute: "1 minute"
    case .fiveMinutes: "5 minutes"
    }
  }
}
