import Foundation
import Kanna

func scrapeSessions(filterBy filterYear: Int? = nil, session filterSession: String? = nil) -> [Session] {
  var sessions: [Session] = []

  (2012...2017).forEach { year in
    if let filter = filterYear, year != filter {
      return
    }
    sessions.append(contentsOf: scrapeSessions(for: year, filterBy: filterSession))
  }
  return sessions
}

fileprivate var baseUrl: URL {
  return URL(string: "https://developer.apple.com")!
}

fileprivate func wwdcUrlPath(for year: Int) -> String {
  return "/videos/wwdc\(year)"
}

fileprivate func wwdcUrl(for year: Int) -> URL {
  return URL(string: wwdcUrlPath(for: year), relativeTo: baseUrl)!
}

func scrapeSessions(for year: Int, filterBy filterSession: String? = nil) -> [Session] {
  var sessions: [Session] = []

  guard let yearDoc = HTML(url: wwdcUrl(for: year), encoding: .utf8) else {
    print("Could not read URL for year \(year)")
    return sessions
  }

  if debugEnabled { print("Scraping \(wwdcUrl(for: year))") }

  yearDoc.xpath("//li[contains(@class, 'collection-focus-group')]").forEach { li in
    guard
      case .NodeSet(let children) = li.xpath("child::*"),
      let header = children.first,
      let items = children.last,
      let track = header.content?.trimmingCharacters(in: .whitespacesAndNewlines)
      else {
        return
    }
    if debugEnabled { print("Scanning sessions in track: \(track)") }

    items.xpath(".//a").forEach { a in
      guard
        let href = a["href"],
        let hrefUrl = URL(string: href),
        let image = a.xpath("child::*").first,
        let imageUrlValue = image["src"],
        let imageUrl = URL(string: imageUrlValue),
        let title = image["alt"],
        let sessionUrl = URL(string: href, relativeTo: baseUrl),
        let sessionDoc = HTML(url: sessionUrl, encoding: .utf8)
        else {
          return
      }
      let number = hrefUrl.lastPathComponent

      if let filter = filterSession, number != filter {
        return
      }

      if debugEnabled {
        print("Collecting \(year) session #\(String(describing: number))...")
        print("Collected title: \(title)")
        print("Collected image URL: \(imageUrlValue)")
        print("Following link to \(String(describing: href))")
      }

      var collectedDescription: String?
      var collectedFocuses: String?

      let detailsNodes = sessionDoc.xpath("//li[contains(@data-supplement-id, 'details')]")
      detailsNodes.forEach { li in
        guard let `class` = li["class"], `class`.range(of: "supplement details") != nil else {
          return
        }

        let paragraphs = li.xpath(".//p")
        guard paragraphs.count >= 2 else {
          return
        }

        guard
          let pDescription = paragraphs[0].text,
          let tagsLine = paragraphs[1].text
          else {
            return
        }

        collectedDescription = pDescription

        let tags = tagsLine.components(separatedBy: " - ")

        guard let pFocuses = tags.last else {
          return
        }

        collectedFocuses = pFocuses

        if debugEnabled {
          print("Collected description: \(String(describing: collectedDescription))")
          print("Collected track: \(String(describing: collectedFocuses))")
        }
      }

      var collectedSdVideoUrl: URL?
      var collectedHdVideoUrl: URL?

      let resourcesNodes = sessionDoc.xpath("//li[contains(@data-supplement-id, 'resources')]")
      resourcesNodes.forEach { li in
        guard let `class` = li["class"], `class`.range(of: "supplement resources") != nil else {
          return
        }

        let videosNode = li.xpath(".//li[contains(@class, 'video')]")
        if let li = videosNode.first {
          let videoLinks = li.xpath(".//a")
          videoLinks.forEach { a in
            guard let text = a.innerHTML else {
              return
            }
            switch text {
            case "HD Video":
              if debugEnabled { print("Collected HD video URL \(String(describing: a["href"]))") }
              guard let value = a["href"], let url = URL(string: value) else {
                return
              }
              collectedHdVideoUrl = url
            case "SD Video":
              if debugEnabled { print("Collected SD video URL \(String(describing: a["href"]))") }
              guard let value = a["href"], let url = URL(string: value) else {
                return
              }
              collectedSdVideoUrl = url
            default:
              break
            }
          }
        }
      }

      guard
        let description = collectedDescription,
        let focuses = collectedFocuses,
        let sdVideoUrl = collectedSdVideoUrl,
        let hdVideoUrl = collectedHdVideoUrl
        else {
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
        vtt: nil,
        year: yearString
      )
      sessions.append(session)
    }
  }
  return sessions
}
