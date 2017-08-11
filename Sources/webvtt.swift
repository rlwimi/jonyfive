import Foundation
import Guaka
import FileUtils

var webvttCommand = Command(
  usage: "webvtt", configuration: configuration, run: execute)

fileprivate let methodOption = Flag(
  shortName: "p",
  longName: "playlist",
  type: Bool.self,
  description: "WebVTT cues acquisition method. Default is false for direct download.\n\t[true] Concatenate HLS subtitles playlists.\n\t[false] Download file from the URL with expected format.",
  required: false,
  inheritable: false
)

fileprivate let fallbackOption = Flag(
  shortName: "f",
  longName: "fallback",
  type: Bool.self,
  description: "On failure of acquisition method, fall back to other methods. Default is true.",
  required: false,
  inheritable: false
)

/// Method of acquiring WebVTT cues.
fileprivate enum AcquisitionMethod {
  /// Fetch the full WebVTT file from a likely location. The full WebVTT file is commonly located at
  /// a URL following a particular format, though this does not work for all sessions.  
  case directDownload
  /// Read the session's HLS master playlist, read its subtitles media playlist, fetch each file in
  /// the sequence, and concatenate the files. Perform some post-processing to eliminate artifacts
  /// of concatenation.
  case subtitlesPlaylist
}

/// Strategy for acquiring WebVTT cues.
///
/// Our two methods of acquiring WebVTT cues yield different result sets. The timing can be 
/// different by milliseconds, a largely inconsequential difference. Also, transcription
/// content may differ. Most notably, the direct download transcript typically includes a closing
/// caption ("Thank you", or "[Applause]") not included in the streaming captions.
fileprivate enum AcquisitionStrategy {
  /// Use HLS subtitles playlist file concatenation exclusively.
  case onlySubtitlesPlaylist
  /// Use direct download, exclusively.
  case onlyDirectDownload
  /// Attempt subtitles playlist file concatenation, falling back to URL download if necessary.
  case preferSubtitlesPlaylist
  /// Attempt URL download, falling back to subtitles playlist file concatenation, if necessary.
  case preferDirectDownload

  var methods: [AcquisitionMethod] {
    switch self {
    case .onlySubtitlesPlaylist:
      return [.subtitlesPlaylist]
    case .onlyDirectDownload:
      return [.directDownload]
    case .preferSubtitlesPlaylist:
      return [.subtitlesPlaylist, .directDownload]
    case .preferDirectDownload:
      return [.directDownload, .subtitlesPlaylist]
    }
  }
}

fileprivate var acquisitionStrategy: AcquisitionStrategy = .preferSubtitlesPlaylist

private func configuration(command: Command) {
  command.shortMessage = "download WebVTT files"
  command.longMessage = "Download each session's WebVTT file, write to disk."

  command.add(flags: [methodOption, fallbackOption])

  command.preRun = { flags, args in
    let usePlaylists = flags.getBool(name: methodOption.longName) ?? false
    let fallback = flags.getBool(name: fallbackOption.longName) ?? true

    if usePlaylists && fallback {
      acquisitionStrategy = .preferSubtitlesPlaylist
    } else if usePlaylists && fallback == false {
      acquisitionStrategy = .onlySubtitlesPlaylist
    } else if usePlaylists == false && fallback {
      acquisitionStrategy = .preferDirectDownload
    } else if usePlaylists == false && fallback == false {
      acquisitionStrategy = .onlyDirectDownload
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

    if var webVttText = acquireWebVttText(for: session, using: acquisitionStrategy.methods) {
      webVttText = normalize(webVttText)
      write(webVttText, for: session)
    }
  }
}

fileprivate var path: String {
  return outputPath?.path ?? "."
}

fileprivate func path(for session: Session) -> String {
  return [path, String(session.year), "\(session.number).vtt"].joined(separator: "/")
}

fileprivate func acquireWebVttText(for session: Session, using methods: [AcquisitionMethod]) -> String? {
  for method in methods {
    if let text = acquireWebVttText(for: session, using: method) {
      return text
    }
  }
  return nil
}

fileprivate func acquireWebVttText(for session: Session, using method: AcquisitionMethod) -> String? {
  switch method {
  case .directDownload:
    return webVttText(from: session.webVtt)
  case .subtitlesPlaylist:
    return concatenateSubtitlesPlaylistFiles(for: session)
  }
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
