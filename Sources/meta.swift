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

    guard
      let yearUrl = URL(string: "https://developer.apple.com/videos/wwdc\(year)"),
      let doc = HTML(url: yearUrl, encoding: .utf8)
      else {
        print("Could not read URL for year \(year)")
        return
    }
    print("\(yearUrl)")
  }
}
