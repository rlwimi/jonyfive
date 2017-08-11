import Foundation
import Guaka

var rootCommand = Command(usage: "jonyfive", configuration: configuration, run: execute)

private let verboseOption = Flag(
  shortName: "v",
  longName: "verbose",
  value: false,
  description: "show work along the way",
  inheritable: true
)

private let yearOption = Flag(
  shortName: "y",
  longName: "year",
  type: Int.self,
  description: "filter by year",
  required: false,
  inheritable: true
)

private let sessionOption = Flag(
  shortName: "s",
  longName: "session",
  type: String.self,
  description: "filter by session",
  required: false,
  inheritable: true
)

private let outputPathOption = Flag(
  shortName: "o",
  longName: "output",
  type: String.self,
  description: "output path",
  required: false,
  inheritable: true
)

var verboseEnabled = false
var filterYear: Int?
var filterSession: String?
var outputPath: URL?

private func configuration(command: Command) {
  command.longMessage = "Collect public information available at Apple's developer site and act on it in various ways."
  command.add(flags: [verboseOption, yearOption, sessionOption, outputPathOption])

  command.inheritablePreRun = { flags, args in

    if let enabled = flags.getBool(name: verboseOption.longName) {
      verboseEnabled = enabled
    }

    if let year = flags.getInt(name: yearOption.longName) {
      // TODO: can we hook into validation to fail the command?
      if year < 2012 || year > 2017 {
        print("Year not supported: \(year)")
        return false
      }
      filterYear = year
    }

    if let session = flags.getString(name: sessionOption.longName) {
      if filterYear == nil {
        print("Session filtering requires year filtering. Use `--year` flag to select a year.")
        return false
      } else {
        filterSession = session
      }
    }

    if let output = flags.getString(name: outputPathOption.longName) {
      outputPath = URL(fileURLWithPath: output)
    }

    return true
  }
}

private func execute(flags: Flags, args: [String]) {
}
