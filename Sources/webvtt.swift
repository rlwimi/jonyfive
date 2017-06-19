import Foundation
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

    var vttText = webVttText(from: vttUrl)
    if vttText == nil {
      print("Attempting fallback, concatenating m3u8 sequence files...")
      vttText = concatenateM3u8SequenceFiles(for: session)
    }

    if let vttText = vttText {
      write(vttText, for: session)
    } else {
      print("Fallback concatenation failed.")
    }
  }
}

fileprivate var path: String {
  return outputPath?.path ?? "."
}

fileprivate func path(for session: Session) -> String {
  return [path, String(session.year), "\(session.number).vtt"].joined(separator: "/")
}

fileprivate func webVttText(from url: URL) -> String? {
  var vttText: String!
  do {
    print("Fetching WebVTT from \(url.absoluteString)")
    vttText = try String(contentsOf: url)
  } catch {
    print("Could not fetch WebVTT at \(url.absoluteString)")
    return nil
  }

  if vttText.range(of: "WEBVTT") == nil {
    print("Received non-WebVTT response")
    return nil
  }

  return vttText
}

fileprivate func concatenateM3u8SequenceFiles(for session: Session) -> String? {
  let queryless = session.downloadSD.deletingQuery
  let baseUrl = queryless.deletingLastPathComponent()
  let m3u8Url = baseUrl.appendingPathComponent("subtitles/eng/prog_index.m3u8")

  var vttText = ""
  var m3u8Text: String = ""

  do {
    m3u8Text = try String(contentsOf: m3u8Url, encoding: .utf8)
  } catch {
    print("Could not fetch m3u8: \(error)")
  }

  if let signature = m3u8Text.components(separatedBy: .whitespacesAndNewlines).first {
    if signature.range(of: "#EXTM3U") == nil {
      print("m3u8 unavailable")
      return nil
    }
  }

  let fileLines = m3u8Text
    .components(separatedBy: .newlines)
    .filter { $0.range(of: ".webvtt") != nil }

  for fileLine in fileLines {
    let file = fileLine.trimmingCharacters(in: .whitespacesAndNewlines)
    let fileUrl = baseUrl.appendingPathComponent("subtitles/eng/\(file)")
    do {
      let fileText = try String(contentsOf: fileUrl, encoding: .utf8)
      vttText.append(fileText)
    } catch {
      print("Could not fetch m3u8 sequence file: \(fileUrl)")
      return nil
    }
  }

  vttText = vttText.trimmingCharacters(in: .whitespacesAndNewlines)
  if vttText.isEmpty {
    return nil
  } else {
    vttText = normalize(vttText)
    return vttText
  }
}

/// Fixes issues created by concatenating subtitle m3u8 sequence files.
fileprivate func normalize(_ vttText: String) -> String {
  var text = removeCarriageReturns(from: vttText)
  text = removeRedundantFileSignatures(from: text)
  text = removeTimestampHeaders(from: text)
  text = removeRedundantCues(from: text)
  return text
}

/// Line breaks within cue text are CRLF, while the rest of the file uses LF. Convert entire file to
/// LF, simplifying processing and generally making life easier.
fileprivate func removeCarriageReturns(from text: String) -> String {
  return text.replacingOccurrences(of: "\r\n", with: "\n")
}

/// A WebVTT file begins with file signature "WEBVTT" to identify it as such. Processing removes
/// subsequent `WEBVTT` lines introduced by concatenating secondary sequence files.
fileprivate func removeRedundantFileSignatures(from webVttText: String) -> String {
  let lines = webVttText.components(separatedBy: .newlines)
  let filtered = lines.filter { $0.range(of: "WEBVTT") == nil }
  let text = "WEBVTT\n".appending(filtered.joined(separator: "\n"))
  return text
}

/// The `X-TIMESTAMP-MAP` header synchronizes timestamps between audio and video. In a monolithic
/// WebVTT file, synchronization is unnecessary. Remove these headers.
fileprivate func removeTimestampHeaders(from webVttText: String) -> String {
  let lines = webVttText.components(separatedBy: .newlines)
  let filtered = lines.filter { line in
    let include = line.range(of: "X-TIMESTAMP-MAP") == nil
    return include
  }//$0.range(of: "X-TIMESTAMP-MAP") == nil }
  var text = filtered.joined(separator: "\n")
  text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
  return text
}

/// Cues are intended to be unique, and concatenation introduces redundant cues.
/// - note: Handles one cue repeated once. Does not handle multiple repetition or repetition of
///         multiple cues.
fileprivate func removeRedundantCues(from webVttText: String) -> String {
  // Hypothesis is that splitting on "\n\n" effectively chunks by cue, which supports a minimal
  // comparison of consecutive elements. Line-by-line processing would be significantly more
  // complex with multiple comparisons per element and handling false matching of empty lines.
  let lines = webVttText.components(separatedBy: "\n\n")

  guard lines.count > 1 else {
    return webVttText
  }

  let firstElements = lines[0..<lines.count-1]
  let secondElements = lines[1..<lines.count]

  var cues: [String] = []
  var repeated = false
  for (first, second) in zip(firstElements, secondElements) {
    if repeated == false {
      cues.append(first)
    }
    repeated = first == second
  }

  let text = cues.joined(separator: "\n\n")
  return text
}

fileprivate func write(_ text: String, for session: Session) {
  print("Writing WebVTT for \(session.year) session #\(session.number) to \(path(for: session))...", terminator: "")
  do {
    try text.write(toFile: path(for: session))
  } catch {
    print(error)
  }
  print("done.")
}
