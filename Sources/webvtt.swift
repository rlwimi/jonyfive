import Guaka

var webvttCommand = Command(
  usage: "webvtt", configuration: configuration, run: execute)


private func configuration(command: Command) {
  command.shortMessage = "download WebVTT files"
  command.longMessage = "Download each session's WebVTT file, write to disk."
}

private func execute(flags: Flags, args: [String]) {
  let sessions = scrapeSessions(filterBy: filterYear, session: filterSession)
  sessions.forEach { session in
    guard let vttUrl = session.vtt else {
      return
    }
    var vttText: String!
    do {
      vttText = try String(contentsOf: vttUrl)
    } catch {
      print("Could not fetch WebVTT at \(vttUrl.absoluteString)")
    }
    print("\(vttText)")
  }
}
