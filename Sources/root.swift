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

private func configuration(command: Command) {
  command.longMessage = "Collect public information available at Apple's developer site and act on it in various ways."
  command.add(flags: [debug, year])

  command.inheritablePreRun = { flags, args in
    if let year = flags.getInt(name: year.longName), year < 2012 || year > 2017 {
      // TODO: can we hook into validation to fail the command?
      print("Year not supported: \(year)q")
      return false
    }
    return true
  }
}

private func execute(flags: Flags, args: [String]) {
}
