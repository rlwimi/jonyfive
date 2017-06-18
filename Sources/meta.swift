import Foundation
import Guaka
import Kanna


var metaCommand = Command(usage: "meta", configuration: configuration, run: execute)


private func configuration(command: Command) {
  command.shortMessage = "Collect session information in a JSON file."
  command.longMessage = "Collect meta information on each session, write it to a JSON file."
}

private func execute(flags: Flags, args: [String]) {
  print("calling meta")

  let baseUrl = URL(string: "https://developer.apple.com")!

  guard let doc = HTML(url: baseUrl, encoding: .utf8) else {
    return
  }

  if let debug = flags.getBool(name: debug.longName), debug {
    print("\(doc.title ?? "no title")")
  }
}
