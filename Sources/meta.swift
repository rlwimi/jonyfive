import Guaka

var metaCommand = Command(usage: "meta", configuration: configuration, run: execute)


private func configuration(command: Command) {
  command.shortMessage = "Collect session information in a JSON file."
  command.longMessage = "Collect meta information on each session, write it to a JSON file."
}

private func execute(flags: Flags, args: [String]) {
}
