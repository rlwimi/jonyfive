import Foundation
import Guaka
import Kanna

var metaCommand = Command(usage: "meta", configuration: configuration, run: execute)

private func configuration(command: Command) {
  command.shortMessage = "Collect session information in a JSON file."
  command.longMessage = "Collect meta information on each session, write it to a JSON file."
}

private func execute(flags: Flags, args: [String]) {

  (2012...2017).forEach { year in
    if let filter = filterYear, year != filter {
      return
    }

    let baseUrlValue = "https://developer.apple.com"
    let baseUrl = URL(string: baseUrlValue)!
    let yearUrlValue = "/videos/wwdc\(year)"

    guard
      let yearUrl = URL(string: yearUrlValue, relativeTo: baseUrl),
      let yearDoc = HTML(url: yearUrl, encoding: .utf8)
      else {
        print("Could not read URL for year \(year)")
        return
    }

    if debugEnabled { print("Scraping \(yearUrl)") }

    yearDoc.xpath("//li[contains(@class, 'collection-focus-group')]").forEach { li in
      guard
        case .NodeSet(let children) = li.xpath("child::*"),
        let header = children.first,
        let items = children.last,
        let focus = header.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
          return
      }
      if debugEnabled { print("Collecting sessions in focus: \(focus)") }

      items.xpath(".//a").forEach { a in
        guard
//          let content = a.content?.trimmingCharacters(in: .whitespacesAndNewlines),
          let href = a["href"],
          let hrefUrl = URL(string: href),
          let image = a.xpath("child::*").first,
          let imageUrlValue = image["src"],
//          let imageUrl = URL(string: imageUrlValue),
          let title = image["alt"],
          let sessionUrl = URL(string: href, relativeTo: baseUrl),
          let sessionDoc = HTML(url: sessionUrl, encoding: .utf8)
          else {
            return
        }
        let session = hrefUrl.lastPathComponent

        if let filter = filterSession, let number = Int(session), number != filter {
          return
        }

        if debugEnabled {
          print("Collecting \(year) session #\(String(describing: session))...")
          print("Collected title: \(title)")
          print("Collected image URL: \(imageUrlValue)")
          print("Following link to \(String(describing: href))")
        }

        let detailsNodes = sessionDoc.xpath("//li[contains(@data-supplement-id, 'details')]")
        detailsNodes.forEach { li in
          guard let `class` = li["class"], `class`.range(of: "supplement details") != nil else {
            return
          }

          let paragraphs = li.xpath(".//p")
          guard paragraphs.count >= 2 else {
            return
          }

          let description = paragraphs[0].text
          let tagsLine = paragraphs[1].text
          let tags = tagsLine?.components(separatedBy: " - ")
          let track = tags?.last

          if debugEnabled {
            print("Collected description: \(String(describing: description))")
            print("Collected track: \(String(describing: track))")
          }
        }

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
              case "SD Video":
                if debugEnabled { print("Collected SD video URL \(String(describing: a["href"]))") }
              default:
                break
              }
            }
          }
        }
      }
    }
  }
}
