import Foundation
import Kanna

fileprivate var baseUrl: URL {
  return URL(string: "https://developer.apple.com")!
}

fileprivate func wwdcUrlPath(for year: Int) -> String {
  return "/videos/wwdc\(year)"
}

fileprivate func wwdcUrl(for year: Int) -> URL {
  return URL(string: wwdcUrlPath(for: year), relativeTo: baseUrl)!
}

func scrapeSessions(filterBy filterYear: Int? = nil, session filterSession: String? = nil) -> [Session] {
  var sessions: [Session] = []

  (2012...2017).forEach { year in
    if let filter = filterYear, year != filter {
      return
    }
    sessions.append(contentsOf: scrapeSessions(from: year, filterBy: filterSession))
  }
  return sessions
}

fileprivate func scrapeSessions(from year: Int, filterBy filterSession: String? = nil) -> [Session] {
  guard let yearDoc = HTML(url: wwdcUrl(for: year), encoding: .utf8) else {
    if verboseEnabled { print("could not read URL for year \(year)") }
    return []
  }

  if verboseEnabled { print("Scraping \(wwdcUrl(for: year))") }

  var sessions: [Session] = []

  yearDoc.xpath("//li[contains(@class, 'collection-focus-group')]").forEach { li in
    guard case .NodeSet(let nodes) = li.xpath("child::*") else {
      return
    }
    sessions.append(contentsOf: scrapeSessions(from: year, inTrackWith: nodes))
  }
  return sessions
}

fileprivate func scrapeSessions(from year: Int, inTrackWith nodes: XMLNodeSet) -> [Session] {
  guard
    let header = nodes.first,
    let items = nodes.last,
    let track = header.content?.trimmingCharacters(in: .whitespacesAndNewlines)
    else {
      if verboseEnabled { print("could not parse node set: \(String(describing: nodes.toHTML))") }
      return []
  }
  if verboseEnabled { print("Scanning sessions in track: \(track)") }

  var sessions: [Session] = []

  var sessionImages: [Identifier<Session>: URL] = [:]

  items.xpath(".//a").forEach { anchor in
    let number = scrapeSessionNumber(from: anchor)
    let identifier = Session.makeIdentifier(conference: .wwdc, year: String(year), number: number)

    // Sessions before 2015 do not have an image. If this is an image anchor, dig the URL, cache, and pass.
    if let imageUrl = scrapeSessionImage(from: anchor) {
      sessionImages[identifier] = imageUrl
      return
    }

    // `anchor` is the title link, which proceeds any image link.

    let imageUrl = sessionImages[identifier]

    let title = scrapeSessionTitle(from: anchor)
    let webpageUrl = scrapeSessionPageUrl(from: anchor)

    if let filter = filterSession, number != filter {
      return
    }

    guard let sessionDoc = HTML(url: webpageUrl, encoding: .utf8) else {
      if verboseEnabled { print("could not read session page: \(webpageUrl.absoluteString)") }
      return
    }

    if verboseEnabled { print("Scraping \(year) session #\(number)...", terminator: "") }

    guard let (description, focuses) = scrapeSessionDetails(from: sessionDoc) else {
      if verboseEnabled { print("could not find the description of \(year) session #\(number)") }
      return
    }

    guard let (sdVideoUrl, hdVideoUrl) = scrapeSessionResources(from: sessionDoc) else {
      if verboseEnabled { print("could not find any resources for \(year) session #\(number)") }
      return
    }

    let yearString = String(year)
    let session = Session(
      conference: .wwdc,
      description: description,
      downloadHD: hdVideoUrl,
      downloadSD: sdVideoUrl,
      duration: nil,
      focuses: focuses.components(separatedBy: ", ").map(Focus.init(rawValue:)).flatMap({ $0 }),
      image: imageUrl,
      number: number,
      title: title,
      track: Track(rawValue: track)!,
      year: yearString
    )

    if verboseEnabled { print("done.") }

    sessions.append(session)
  }
  return sessions
}

fileprivate func scrapeSessionNumber(from anchor: Kanna.XMLElement) -> String {
  return scrapeSessionPageUrl(from: anchor).lastPathComponent
}

fileprivate func scrapeSessionImage(from anchor: Kanna.XMLElement) -> URL? {
  guard
    let image = anchor.xpath("child::*").first,
    let imageUrlValue = image["src"],
    let imageUrl = URL(string: imageUrlValue)
    else {
      return nil
  }
  return imageUrl
}

fileprivate func scrapeSessionTitle(from anchor: Kanna.XMLElement) -> String {
  return anchor.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

fileprivate func scrapeSessionPageUrl(from anchor: Kanna.XMLElement) -> URL {
  guard
    let href = anchor["href"],
    let hrefUrl = URL(string: href, relativeTo: baseUrl)
    else {
      return baseUrl
  }
  return hrefUrl
}

fileprivate func scrapeSessionDetails(from doc: HTMLDocument) -> (description: String, focuses: String)? {
  for listItem in doc.xpath("//li[contains(@data-supplement-id, 'details')]") {
    // Skip the details tab element.
    if let `class` = listItem["class"], `class`.range(of: "supplement details") == nil {
      continue
    }

    let paragraphs = listItem.xpath(".//p")
    guard paragraphs.count >= 2 else {
      return nil
    }

    guard
      let description = paragraphs[0].text,
      let tagsLine = paragraphs[1].text
      else {
        return nil
    }

    let tags = tagsLine.components(separatedBy: " - ")

    guard let focuses = tags.last else {
      return nil
    }

    return (description, focuses)
  }

  return nil
}

fileprivate func scrapeSessionResources(from doc: HTMLDocument) -> (sdVideoUrl: URL, hdVideoUrl: URL)? {
  for resourcesListItem in doc.xpath("//li[contains(@data-supplement-id, 'details')]") {
    // Skip the tab element, it's the tab's content we want.
    if let `class` = resourcesListItem["class"], `class`.range(of: "supplement details") == nil {
      continue
    }

    var sdVideoUrl: URL?
    var hdVideoUrl: URL?

    resourcesListItem.xpath(".//a").forEach { anchor in
      guard let text = anchor.innerHTML else {
        return
      }
      switch text {
      case "HD Video":
        guard let value = anchor["href"], let url = URL(string: value) else {
          return
        }
        hdVideoUrl = url
      case "SD Video":
        guard let value = anchor["href"], let url = URL(string: value) else {
          return
        }
        sdVideoUrl = url
      default:
        // Not yet handling non-video resources
        break
      }
    }

    // Not handling the case when missing only SD or HD
    if let sdVideoUrl = sdVideoUrl, let hdVideoUrl = hdVideoUrl {
      return (sdVideoUrl, hdVideoUrl)
    }
  }
  return nil
}
