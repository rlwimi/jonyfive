import Foundation
import Guaka
import FileUtils

var webvttCommand = Command(
  usage: "webvtt", configuration: configuration, run: execute)

fileprivate let subtitlesPlaylistOption = Flag(
  shortName: "p",
  longName: "playlist",
  type: Bool.self,
  description: "WebVTT cues acquisition strategy\n\t[no flag] Download URL, fallback to subtitles playlist.\n\t[true] Use HLS subtitles playlist exclusively.\n\t[false] Do not fall back to HLS subtitles playlist.",
  required: false,
  inheritable: false
)

/// Strategy for acquiring WebVTT cues.
///
/// There are two methods of acquiring a session's WebVTT cues (captions, subtitles):
///
/// 1. Fetch the full WebVTT file from a likely location. The full WebVTT file is commonly located
///    at a URL following a particular format, though this does not work for all sessions.
/// 2. Read the session's HLS master playlist, read its subtitles media playlist, fetch each file
///    in the sequence, and concatenate the files. Perform some post-processing to eliminate
///    artifacts of concatenation.
///
/// - note: For each session, one, none, or both strategies may be effective. When both are
///         effective, the content is not always identical. There may be millisecond differences in
///         cue timing or even cue content differences in rare cases.
fileprivate enum AcquisitionStrategy {
  /// Attempt URL download, fall back to subtitles playlist file concatenation, if necessary.
  case fallback
  /// Use HLS subtitles playlist file concatenation exclusively.
  case useSubtitlesPlaylist
  /// Use direct download, exclusively.
  case useDirectDownload

  var usesDownloadUrl: Bool {
    switch self {
    case .fallback:
      return true
    case .useSubtitlesPlaylist:
      return false
    case .useDirectDownload:
      return true
    }
  }

  var usesSubtitlesPlaylist: Bool {
    switch self {
    case .fallback:
      return true
    case .useSubtitlesPlaylist:
      return true
    case .useDirectDownload:
      return false
    }
  }
}

fileprivate var acquisitionStrategy: AcquisitionStrategy = .fallback

private func configuration(command: Command) {
  command.shortMessage = "download WebVTT files"
  command.longMessage = "Download each session's WebVTT file, write to disk."

  command.add(flag: subtitlesPlaylistOption)

  command.preRun = { flags, args in
    if let usePlaylists = flags.getBool(name: subtitlesPlaylistOption.longName) {
      acquisitionStrategy = (usePlaylists ? .useSubtitlesPlaylist : .useDirectDownload)
    }
    return true
  }
}

private func execute(flags: Flags, args: [String]) {
  let sessions = scrapeSessions(filterBy: filterYear, session: filterSession)

  Directory.create(atPath: path)

  let years = Set(sessions.map { String($0.year) })
  years.forEach { year in
    Directory.create(atPath: [path, year].joined(separator: "/"))
  }

  sessions.forEach { session in
    if verboseEnabled { print("##### \(session.year) session #\(session.number) #####") }

    var vttText: String? = nil

    if acquisitionStrategy.usesDownloadUrl {
      vttText = webVttText(from: session.webVttUrl)
    }

    if vttText == nil && acquisitionStrategy.usesSubtitlesPlaylist {
      vttText = concatenateSubtitlesPlaylistFiles(for: session)
    }

    if var vttText = vttText {
      vttText = normalize(vttText)
      write(vttText, for: session)
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
    if verboseEnabled { print("Fetching WebVTT from \(url.absoluteString)") }
    vttText = try String(contentsOf: url)
  } catch {
    if verboseEnabled { print("Could not fetch WebVTT at \(url.absoluteString)") }
    return nil
  }

  if vttText.range(of: "WEBVTT") == nil {
    if verboseEnabled { print("Received non-WebVTT response") }
    return nil
  }

  return vttText
}

fileprivate func concatenateSubtitlesPlaylistFiles(for session: Session) -> String? {
  if verboseEnabled { print("Concatenating subtitles media playlist files") }

  let queryless = session.downloadSD.deletingQuery
  let baseUrl = queryless.deletingLastPathComponent()
  let m3u8Url = baseUrl.appendingPathComponent("subtitles/eng/prog_index.m3u8")

  var vttText = ""
  var m3u8Text: String = ""

  do {
    m3u8Text = try String(contentsOf: m3u8Url, encoding: .utf8)
  } catch {
    if verboseEnabled { print("Could not fetch subtitles media playlist: \(error)") }
  }

  if let signature = m3u8Text.components(separatedBy: .whitespacesAndNewlines).first {
    if signature.range(of: "#EXTM3U") == nil {
      if verboseEnabled { print("Subtitles media playlist unavailable") }
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
      if verboseEnabled { print("Could not fetch subtitles sequence file: \(fileUrl)") }
      return nil
    }
  }

  vttText = vttText.trimmingCharacters(in: .whitespacesAndNewlines)
  if vttText.isEmpty {
    return nil
  } else {
    return vttText
  }
}

/// Resolves artifacts of subtitle media playlist files concatenation.
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
  if verboseEnabled { print("Writing WebVTT for \(session.year) session #\(session.number) to \(path(for: session))...", terminator: "") }
  do {
    try text.write(toFile: path(for: session))
  } catch {
    if verboseEnabled { print(error) }
  }
  if verboseEnabled { print("done.") }
}
