import Guaka

var rootCommand = Command(usage: "wwwww", configuration: configuration, run: execute)

private func configuration(command: Command) {
  command.longMessage = "Collect public information available at Apple's developer site and act on it in various ways."
}

private func execute(flags: Flags, args: [String]) {
}
