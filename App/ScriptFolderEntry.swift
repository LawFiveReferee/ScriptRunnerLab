import Foundation
import ScriptRunnerKit

struct ScriptFolderEntry: Identifiable {
  var url: URL
  var relativePath: String
  var descriptor: ScriptDescriptor

  var id: String {
    url.standardizedFileURL.path(percentEncoded: false)
  }
}
