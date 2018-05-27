import Foundation
import Guaka
import HTMLEntities
import Yams

var metaCommand = Command(usage: "meta", configuration: configuration, run: execute)

fileprivate let outputFormatOption = Flag(
  shortName: "f",
  longName: "format",
  type: String.self,
  description: "output format: json (default, for Major Input) or yaml (for ASCIIwwdc)",
  required: false,
  inheritable: false
)

fileprivate enum Format: String {
  /// Format used by Major Input. Includes all scraped information.
  case json
  /// Format used by ASCIIwwdc.com. Includes limited information.
  case yaml
}

fileprivate var format: Format = .json

private func configuration(command: Command) {
  command.shortMessage = "Collect session information in a file."
  command.longMessage = "Collect meta information on each session, write it to a file."

  command.add(flags: [outputFormatOption])

  command.preRun = { flags, args in
    guard let formatRawValue = flags.getString(name: outputFormatOption.longName) else {
      return true
    }
    guard let formatValue = Format(rawValue: formatRawValue) else {
      print("Invalid output format \"\(formatRawValue)\".")
      return false
    }
    format = formatValue
    return true
  }
}

private func execute(flags: Flags, args: [String]) {
  let sessions = scrapeSessions(filterBy: filterYear, session: filterSession)
  switch format {
  case .json:
    outputJson(for: sessions)
  case .yaml:
    outputYaml(for: sessions)
  }
}

private func outputJson(for sessions: [Session]) {
  do {
    let dictionaries = sessions.map({ $0.dictionary })
    try JSONSerialization
      .data(withJSONObject: dictionaries, options: .prettyPrinted)
      .write(to: outputPath ?? URL(fileURLWithPath: "./sessions.json"))
  } catch {
    if verboseEnabled { print(error) }
  }
}

private func outputYaml(for sessions: [Session]) {
  do {
    let yaml = try dump(object: sessions.asciiWwdcYamlObject, width: -1)
    try yaml.write(to: outputPath ?? URL(fileURLWithPath: "./sessions.yml"), atomically: true, encoding: .utf8)
  } catch {
    if verboseEnabled { print(error) }
  }
}

extension Array where Element == Session {
  /// Provides an object emittable as YAML of the form expected by ASCIIwwdc.
  var asciiWwdcYamlObject: [Node: NodeRepresentable] {
    var structured: [Node: NodeRepresentable] = [:]
    forEach { session in
      let key = Node(session.number)
      let value = [
        ":title": Node(session.title.asciiwwdcEscaped),
        ":track": Node(session.track.rawValue),
        ":description": Node(session.description.asciiwwdcEscaped)
      ]
      structured[key] = value
    }
    return structured
  }
}

private extension String {
  /// Mimic escaping found in existing asciiwwdc.com YAML.
  ///
  /// Yams emits colon-containing strings in single quotes, but asciiwwdc.com may not expect this.
  /// asciiwwdc.com may expect HTML enitities and not unicode escape sequences.
  var asciiwwdcEscaped: String {
    return self
      .replacingOccurrences(of: ":", with: "&#58;")
      .htmlEscape(allowUnsafeSymbols: false, decimal: true, encodeEverything: false, useNamedReferences: true)
  }
}
