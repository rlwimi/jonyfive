import Foundation
import Guaka

var metaCommand = Command(usage: "meta", configuration: configuration, run: execute)

fileprivate let outputFormatOption = Flag(
  shortName: "f",
  longName: "format",
  type: String.self,
  description: "output format: json (default, for Major Input) or yaml (for ASCIIwwdc)",
  required: false,
  inheritable: false
)

fileprivate enum Format: String {
  /// Format used by Major Input. Includes all scraped information.
  case json
  /// Format used by ASCIIwwdc.com. Includes limited information.
  case yaml
}

fileprivate var format: Format = .json

private func configuration(command: Command) {
  command.shortMessage = "Collect session information in a file."
  command.longMessage = "Collect meta information on each session, write it to a file."

  command.add(flags: [outputFormatOption])

  command.preRun = { flags, args in
    guard let formatRawValue = flags.getString(name: outputFormatOption.longName) else {
      return true
    }
    guard let formatValue = Format(rawValue: formatRawValue) else {
      print("Invalid output format \"\(formatRawValue)\".")
      return false
    }
    format = formatValue
    return true
  }
}

private func execute(flags: Flags, args: [String]) {
  do {
    let sessions = scrapeSessions(filterBy: filterYear, session: filterSession)
    let dictionaries = sessions.map({ $0.dictionary })
    try JSONSerialization
      .data(withJSONObject: dictionaries, options: .prettyPrinted)
      .write(to: outputPath ?? URL(fileURLWithPath: "./sessions.json"))
  } catch {
    if verboseEnabled { print(error) }
  }
}
