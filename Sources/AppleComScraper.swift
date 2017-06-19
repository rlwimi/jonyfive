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

func scrapeSessions(from year: Int, filterBy filterSession: String? = nil) -> [Session] {
  guard let yearDoc = HTML(url: wwdcUrl(for: year), encoding: .utf8) else {
    print("could not read URL for year \(year)")
    return []
  }

  if debugEnabled { print("Scraping \(wwdcUrl(for: year))") }

  var sessions: [Session] = []

  yearDoc.xpath("//li[contains(@class, 'collection-focus-group')]").forEach { li in
    guard case .NodeSet(let nodes) = li.xpath("child::*") else {
      return
    }
    sessions.append(contentsOf: scrapeSessions(from: year, inTrackWith: nodes))
  }
  return sessions
}

func scrapeSessions(from year: Int, inTrackWith nodes: XMLNodeSet) -> [Session] {
  guard
    let header = nodes.first,
    let items = nodes.last,
    let track = header.content?.trimmingCharacters(in: .whitespacesAndNewlines)
    else {
      print("could not parse node set: \(String(describing: nodes.toHTML))")
      return []
  }
  if debugEnabled { print("Scanning sessions in track: \(track)") }

  var sessions: [Session] = []

  items.xpath(".//a").forEach { anchor in
    // There are two links, the image and the title. Skip the title. We'll use the image's alt text.
    guard let _ = anchor.xpath(".//img").first else {
      return
    }

    guard let (number, title, imageUrl, webpageUrl) = scrapeSessionInfo(from: anchor) else {
      return
    }

    if let filter = filterSession, number != filter {
      return
    }

    guard let sessionDoc = HTML(url: webpageUrl, encoding: .utf8) else {
      print("could not read session page: \(webpageUrl.absoluteString)")
      return
    }

    if debugEnabled {
      print("Scraping \(year) session #\(number)...", terminator: "")
    }

    guard let (description, focuses) = scrapeSessionDetails(from: sessionDoc) else {
      print("could not find details for \(year) session #\(number)")
      return
    }

    guard let (sdVideoUrl, hdVideoUrl) = scrapeSessionResources(from: sessionDoc) else {
      print("could not find resources for \(year) session #\(number)")
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

    if debugEnabled { print("done.") }

    sessions.append(session)
  }
  return sessions
}

func scrapeSessionInfo(from anchor: Kanna.XMLElement) -> (sessionNumber: String, title: String, imageUrl: URL, webpageUrl: URL)? {
  guard
    let href = anchor["href"],
    let hrefUrl = URL(string: href),
    let image = anchor.xpath("child::*").first,
    let imageUrlValue = image["src"],
    let imageUrl = URL(string: imageUrlValue),
    let title = image["alt"],
    let webpageUrl = URL(string: href, relativeTo: baseUrl)
    else {
      print("could not dig session info out of anchor: \(String(describing: anchor.toHTML))")
      return nil
  }
  let number = hrefUrl.lastPathComponent

  return (number, title, imageUrl, webpageUrl)
}

func scrapeSessionDetails(from doc: HTMLDocument) -> (description: String, focuses: String)? {
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

func scrapeSessionResources(from doc: HTMLDocument) -> (sdVideoUrl: URL, hdVideoUrl: URL)? {
  for resourcesListItem in doc.xpath("//li[contains(@data-supplement-id, 'resources')]") {
    // Skip the resources tab element.
    if let `class` = resourcesListItem["class"], `class`.range(of: "supplement resources") == nil {
      continue
    }

    var sdVideoUrl: URL!
    var hdVideoUrl: URL!

    guard let videosListItem = resourcesListItem.at_xpath(".//li[contains(@class, 'video')]") else {
      print("could not find videos resource node")
      return nil
    }

    videosListItem.xpath(".//a").forEach { anchor in
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
        break
      }
    }
    return (sdVideoUrl, hdVideoUrl)
  }
  return nil
}
