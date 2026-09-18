import Foundation
import SwiftEmbed

/// Per-language sentence → words splitter. Mirrors the Python and Kotlin
/// ports through the shared `word_split_rules.yaml` / `word_split_tests.yaml`
/// in the syllabreak repos.
///
/// Two modes, configured in `Resources/word_split_rules.yaml`:
///
/// * **default** — Latin / Cyrillic / Arabic / Hebrew / Hindi etc. A word is
///   one or more Unicode letters/marks/digits, optionally joined by an
///   apostrophe (straight or curly) or a hyphen. Combining marks (Hebrew
///   points, Arabic harakat, Devanagari matras) attach to the preceding
///   letter.
/// * **cjk** — `cmn`, `jpn`, `kor`. Each Han / Hiragana / Katakana / Hangul
///   character is its own word; Latin/digit runs stay together so
///   "iPhoneを使う" yields ["iPhone", "を", "使", "う"].
public final class WordSplitter: Sendable {
  struct RulesEntry: Codable {
    let lang: String
    let mode: String
  }

  struct RulesData: Codable {
    let rules: [RulesEntry]
  }

  private static var rulesData: RulesData {
    Embedded.getYAML(Bundle.module, path: "word_split_rules.yaml")
  }

  private let modes: [String: String]
  private let defaultRegex: NSRegularExpression
  private let cjkRegex: NSRegularExpression

  public init() {
    var modes: [String: String] = [:]
    for entry in Self.rulesData.rules {
      modes[entry.lang] = entry.mode
    }
    self.modes = modes
    // CJK char ranges baked as literals — ICU doesn't expose Block names
    // in NSRegularExpression. Order matters: the Latin/digit alternative
    // sits first so "iPhoneを使う" keeps "iPhone" intact.
    let cjkChars =
      "\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}\u{F900}-\u{FAFF}"
      + "\u{3040}-\u{309F}\u{30A0}-\u{30FF}\u{AC00}-\u{D7AF}"
    guard
      // ICU regex via NSRegularExpression supports \p{L}\p{M}\p{Nd}.
      let defaultRegex = try? NSRegularExpression(
        pattern: #"[\p{L}\p{M}\p{Nd}]+(?:['’\-][\p{L}\p{M}\p{Nd}]+)*"#
      ),
      let cjkRegex = try? NSRegularExpression(
        pattern: #"[A-Za-z0-9]+(?:['’\-][A-Za-z0-9]+)*|["# + cjkChars + "]"
      )
    else {
      fatalError("WordSplitter regex failed to compile — programmer bug in this file")
    }
    self.defaultRegex = defaultRegex
    self.cjkRegex = cjkRegex
  }

  public func split(_ text: String, lang: String) -> [String] {
    let nsText = text as NSString
    return findNSRanges(text, lang: lang).map { nsText.substring(with: $0) }
  }

  /// Word ranges expressed as Swift `Range<String.Index>` — needed by clients
  /// that highlight or annotate positions in the original text (e.g. iOS
  /// lexeme spans), where re-searching the surface form would be ambiguous
  /// on repeats ("the cat sat on the mat").
  public func findRanges(_ text: String, lang: String) -> [Range<String.Index>] {
    findNSRanges(text, lang: lang).compactMap { Range($0, in: text) }
  }

  private func findNSRanges(_ text: String, lang: String) -> [NSRange] {
    let regex = modes[lang] == "cjk" ? cjkRegex : defaultRegex
    let nsText = text as NSString
    let matches = regex.matches(
      in: text, range: NSRange(location: 0, length: nsText.length)
    )
    return matches.map { $0.range }
  }
}
