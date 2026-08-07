import Foundation

public enum CompatibilityTestResources {
  public static var rootURL: URL? {
    Bundle.module.url(forResource: "CompatibilityTests", withExtension: nil)
  }

  public static func url(for test: CompatibilityTestDefinition) -> URL? {
    rootURL?.appending(path: test.relativePath)
  }
}
