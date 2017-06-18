import Foundation
import Guaka

var rootCommand = Command(usage: "wwwww", configuration: configuration, run: execute)

private let debugOption = Flag(
  shortName: "d",
  longName: "debug",
  value: false,
  description: "Show the work as it is being done.",
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
  type: Int.self,
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

var debugEnabled = false
var filterYear: Int?
var filterSession: Int?
var outputPath: URL?

private func configuration(command: Command) {
  command.longMessage = "Collect public information available at Apple's developer site and act on it in various ways."
  command.add(flags: [debugOption, yearOption, sessionOption, outputPathOption])

  command.inheritablePreRun = { flags, args in

    if let enabled = flags.getBool(name: debugOption.longName) {
      debugEnabled = enabled
    }

    if let year = flags.getInt(name: yearOption.longName) {
      // TODO: can we hook into validation to fail the command?
      if year < 2012 || year > 2017 {
        print("Year not supported: \(year)")
        return false
      }
      filterYear = year
    }

    if let session = flags.getInt(name: sessionOption.longName) {
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
