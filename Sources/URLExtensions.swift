import Foundation

public extension URL {
  /// Return a URL with query removed. If something goes wrong, return the instance.
  var deletingQuery: URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
      return self
    }
    components.query = nil
    guard let url = components.url else {
      return self
    }
    return url
  }
}
