import Guaka

var rootCommand = Command(usage: "wwwww", configuration: configuration, run: execute)

let debug = Flag(
  shortName: "d",
  longName: "debug",
  value: false,
  description: "Show the work as it is being done.",
  inheritable: true
)

let year = Flag(
  shortName: "y",
  longName: "year",
  type: Int.self,
  description: "filter by year",
  required: false,
  inheritable: true
)

let session = Flag(
  shortName: "s",
  longName: "session",
  type: Int.self,
  description: "filter by session",
  required: false,
  inheritable: true
)

var debugEnabled = false
var filterYear: Int?
var filterSession: Int?

private func configuration(command: Command) {
  command.longMessage = "Collect public information available at Apple's developer site and act on it in various ways."
  command.add(flags: [debug, year, session])

  command.inheritablePreRun = { flags, args in

    if let enabled = flags.getBool(name: debug.longName) {
      debugEnabled = enabled
    }

    if let year = flags.getInt(name: year.longName) {
      // TODO: can we hook into validation to fail the command?
      if year < 2012 || year > 2017 {
        print("Year not supported: \(year)")
        return false
      }
      filterYear = year
    }

    if let session = flags.getInt(name: session.longName) {
      if filterYear == nil {
        print("Session filtering requires year filtering. Use `--year` flag to select a year.")
        return false
      } else {
        filterSession = session
      }
    }

    return true
  }
}

private func execute(flags: Flags, args: [String]) {
}
