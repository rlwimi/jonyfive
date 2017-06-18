import Foundation

enum Focus: String {
  case iOS
  case macOS
  case tvOS
  case watchOS
}

enum Track: String {
  case appFrameworks = "App Frameworks"
  case systemFrameworks = "System Frameworks"
  case developerTools = "Developer Tools"
  case featured = "Featured"
  case graphicsAndGames = "Graphics and Games"
  case design = "Design"
  case media = "Media"
  case distribution = "Distribution"
}

enum Conference: String {
  case wwdc = "WWDC"
}

struct Session: Identifiable {
  let identifier: Identifier<Session>
  let conference: Conference
  let description: String
  let downloadHD: URL
  let downloadSD: URL
  let duration: Int?
  let focuses: [Focus]
  let image: URL
  let number: String
  let title: String
  let track: Track
  let vtt: URL?
  let year: String

  init(
    conference: Conference,
    description: String,
    downloadHD: URL,
    downloadSD: URL,
    duration: Int?,
    focuses: [Focus],
    image: URL,
    number: String,
    title: String,
    track: Track,
    vtt: URL?,
    year: String) {

    self.identifier = Session.makeIdentifier(conference: conference, year: year, number: number)
    self.conference = conference
    self.description = description
    self.downloadHD = downloadHD
    self.downloadSD = downloadSD
    self.duration = duration
    self.focuses = focuses
    self.image = image
    self.number = number
    self.title = title
    self.track = track
    self.vtt = vtt
    self.year = year
  }
}

extension Session {
  static func makeIdentifier(conference: Conference, year: String, number: String) -> Identifier<Session> {
    return Identifier(rawValue: [conference.rawValue, year, number].joined(separator: "-"))
  }
}

extension Session: Equatable {

  static func == (lhs: Session, rhs: Session) -> Bool {
    return lhs.year == rhs.year &&
      lhs.number == rhs.number &&
      lhs.description == rhs.description &&
      lhs.downloadHD == rhs.downloadHD &&
      lhs.downloadSD == rhs.downloadSD &&
      lhs.duration == rhs.duration &&
      lhs.focuses == rhs.focuses &&
      lhs.image == rhs.image &&
      lhs.title == rhs.title &&
      lhs.track == rhs.track &&
      lhs.vtt == rhs.vtt
  }
}

extension Session: Hashable {
  var hashValue: Int {
    return identifier.hashValue
  }
}
