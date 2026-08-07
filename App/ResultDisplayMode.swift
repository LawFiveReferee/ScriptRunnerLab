import Foundation

enum ResultDisplayMode: String, CaseIterable, Identifiable {
  case aePrint
  case source

  var id: Self { self }

  var displayName: String {
    switch self {
    case .aePrint: "AE Print"
    case .source: "Source"
    }
  }
}
