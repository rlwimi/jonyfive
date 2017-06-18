import Guaka

var rootCommand = Command(usage: "wwwww", configuration: configuration, run: execute)

let debug = Flag(
  shortName: "d",
  longName: "debug",
  value: false,
  description: "Show the work as it is being done.",
  inheritable: true
)

private func configuration(command: Command) {
  command.longMessage = "Collect public information available at Apple's developer site and act on it in various ways."
  command.add(flag: debug)
}

private func execute(flags: Flags, args: [String]) {
}
