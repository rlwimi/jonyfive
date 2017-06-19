import Guaka
import FileUtils

var webvttCommand = Command(
  usage: "webvtt", configuration: configuration, run: execute)


private func configuration(command: Command) {
  command.shortMessage = "download WebVTT files"
  command.longMessage = "Download each session's WebVTT file, write to disk."
}

private func execute(flags: Flags, args: [String]) {
  let sessions = scrapeSessions(filterBy: filterYear, session: filterSession)

  Directory.create(atPath: path)

  let years = Set(sessions.map { String($0.year) })
  years.forEach { year in
    Directory.create(atPath: [path, year].joined(separator: "/"))
  }

  sessions.forEach { session in
    guard let vttUrl = session.vtt else {
      print("Missing WebVTT URL for \(session.year) session #\(session.number)")
      return
    }
    var vttText: String!
    do {
      print("WebVTT URL: \(vttUrl.absoluteString)")
      vttText = try String(contentsOf: vttUrl)
    } catch {
      print("Could not fetch WebVTT at \(vttUrl.absoluteString)")
    }

    print("Writing WebVTT for \(session.year) session #\(session.number) to \(path(for: session))...", terminator: "")
    do {
      try vttText.write(toFile: path(for: session))
    } catch {
      print(error)
    }
    print("done.")
  }
}

fileprivate var path: String {
  return outputPath?.path ?? "."
}

fileprivate func path(for session: Session) -> String {
  return [path, String(session.year), "\(session.number).vtt"].joined(separator: "/")
}
