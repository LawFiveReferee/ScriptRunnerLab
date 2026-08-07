import Foundation
import Observation

@MainActor
@Observable
public final class FavoriteScriptStore {
  public private(set) var favorites: [FavoriteScript]

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let storageKey: String

  public init(
    defaults: UserDefaults = .standard,
    storageKey: String = "favoriteScripts"
  ) {
    self.defaults = defaults
    self.storageKey = storageKey
    self.favorites = Self.load(defaults: defaults, storageKey: storageKey)
    sortFavorites()
  }

  public func favoriteID(for url: URL) -> UUID? {
    let path = Self.identity(for: url)
    return favorites.first {
      Self.identity(forPath: $0.lastKnownPath) == path
    }?.id
  }

  @discardableResult
  public func add(_ descriptor: ScriptDescriptor) throws -> FavoriteScript {
    if let id = favoriteID(for: descriptor.url),
       let existing = favorites.first(where: { $0.id == id }) {
      return existing
    }

    let favorite = try FavoriteScript(descriptor: descriptor)
    favorites.append(favorite)
    sortFavorites()
    save()
    return favorite
  }

  public func remove(id: UUID) {
    favorites.removeAll { $0.id == id }
    save()
  }

  @discardableResult
  public func replace(id: UUID, with descriptor: ScriptDescriptor) throws -> FavoriteScript {
    guard let index = favorites.firstIndex(where: { $0.id == id }) else {
      throw CocoaError(.fileNoSuchFile)
    }

    let replacement = FavoriteScript(
      id: id,
      replacing: try FavoriteScript(descriptor: descriptor)
    )
    favorites[index] = replacement
    sortFavorites()
    save()
    return replacement
  }

  public func resolveAndRefresh(id: UUID) throws -> FavoriteScriptResolution {
    guard let favorite = favorites.first(where: { $0.id == id }) else {
      throw CocoaError(.fileNoSuchFile)
    }

    let resolution = try favorite.resolvedURL()
    let accessed = resolution.url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        resolution.url.stopAccessingSecurityScopedResource()
      }
    }

    let descriptor = ScriptDescriptor(url: resolution.url)
    let refreshedFavorite = try replace(id: id, with: descriptor)
    return FavoriteScriptResolution(
      favorite: refreshedFavorite,
      url: resolution.url,
      bookmarkWasStale: resolution.isStale
    )
  }

  public func reload() {
    favorites = Self.load(defaults: defaults, storageKey: storageKey)
    sortFavorites()
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(favorites) else { return }
    defaults.set(String(decoding: data, as: UTF8.self), forKey: storageKey)
  }

  private func sortFavorites() {
    favorites.sort {
      $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
    }
  }

  private static func load(
    defaults: UserDefaults,
    storageKey: String
  ) -> [FavoriteScript] {
    guard let storedValue = defaults.string(forKey: storageKey),
          let data = storedValue.data(using: .utf8),
          let favorites = try? JSONDecoder().decode([FavoriteScript].self, from: data) else {
      return []
    }
    return favorites
  }

  private static func identity(for url: URL) -> String {
    url.standardizedFileURL.path(percentEncoded: false)
  }

  private static func identity(forPath path: String) -> String {
    identity(for: URL(fileURLWithPath: path))
  }
}

public struct FavoriteScriptResolution: Sendable {
  public var favorite: FavoriteScript
  public var url: URL
  public var bookmarkWasStale: Bool

  public init(
    favorite: FavoriteScript,
    url: URL,
    bookmarkWasStale: Bool
  ) {
    self.favorite = favorite
    self.url = url
    self.bookmarkWasStale = bookmarkWasStale
  }
}
