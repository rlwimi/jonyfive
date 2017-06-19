import Foundation

extension Session {
  var dictionary: [String: Any] {
    var d: [String: Any] = [:]
    d["description"] = description
    d["download_hd"] = downloadHD.absoluteString
    d["download_sd"] = downloadSD.absoluteString
    d["duration"] = duration ?? nil
    d["focus"] = focuses.map({ $0.rawValue })
    d["image"] = image?.absoluteString
    d["id"] = number
    d["track"] = track.rawValue
    d["title"] = title
    d["year"] = Int(year) ?? nil
    return d
  }
}
