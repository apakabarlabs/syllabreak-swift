import Foundation
import SwiftEmbed

/// Detects a text's language and inserts separators at orthographic syllable boundaries.
public final class Syllabreak: Sendable {
  /// The Unicode soft hyphen used when no custom separator is supplied.
  public static let defaultSoftHyphen = "\u{00AD}"
  private let softHyphen: String
  private let metaRule: MetaRule

  struct RulesData: Codable {
    let rules: [LanguageRule]
  }

  private static var rulesData: RulesData {
    let data: RulesData = Embedded.getYAML(Bundle.module, path: "rules.yaml")
    for rule in data.rules {
      _ = rule.validatedVowelNucleusRules
    }
    return data
  }

  /// Creates a syllabifier with the string inserted at every detected boundary.
  ///
  /// Pass a visible separator such as `"-"` when displaying or testing the result.
  /// The default is U+00AD SOFT HYPHEN.
  ///
  /// - Parameter softHyphen: The boundary marker to insert between syllables.
  public init(softHyphen: String = defaultSoftHyphen) {
    self.softHyphen = softHyphen
    self.metaRule = MetaRule(rules: Self.rulesData.rules)
  }

  /// Returns matching language codes in descending rule-match score order.
  ///
  /// Canonically equivalent NFC and NFD input produces the same result. An empty result
  /// means that the text contains no recognizable letters. The first code is the rule
  /// selected by ``syllabify(_:lang:)`` when `lang` is omitted.
  ///
  /// - Parameter text: Text whose letters are compared with the bundled language rules.
  /// Match scores are based on character coverage; a character unique to one bundled
  /// rule raises that rule to the maximum score.
  ///
  /// - Returns: Matching ISO 639-3 language codes, highest rule-match score first.
  public func detectLanguage(_ text: String) -> [String] {
    let matchingRules = metaRule.findMatches(text.precomposedStringWithCanonicalMapping)
    return matchingRules.map { $0.lang }
  }

  /// Codes of every language the loaded rules cover, in rule-file order.
  ///
  /// - Returns: The language codes accepted by ``syllabify(_:lang:)``.
  public func supportedLanguages() -> [String] {
    metaRule.rules.map { $0.lang }
  }

  private func autoDetectRule(_ text: String) -> LanguageRule? {
    let matchingRules = metaRule.findMatches(text)
    return matchingRules.first
  }

  private func getRuleByLang(_ lang: String) -> LanguageRule? {
    for rule in metaRule.rules where rule.lang == lang {
      return rule
    }
    return nil
  }

  /// Inserts the configured marker at valid syllable boundaries.
  ///
  /// When `lang` is `nil`, the language is detected automatically. The input is returned unchanged
  /// when no rule matches or when the requested language is unsupported. When a rule is
  /// applied, the result is NFC-normalized; unchanged fallback results retain the input's
  /// original Unicode normalization.
  /// Existing punctuation and word spacing are preserved. The method follows bundled orthographic
  /// rules rather than a pronunciation dictionary, so callers should supply `lang` when scripts or
  /// alphabets are shared by several supported languages.
  ///
  /// - Parameters:
  ///   - text: Text to syllabify.
  ///   - lang: An ISO 639-3 code from ``supportedLanguages()``, or `nil` to auto-detect.
  /// - Returns: Text with the configured boundary marker inserted, NFC-normalized when a
  ///   language rule was applied.
  public func syllabify(_ text: String, lang: String? = nil) -> String {
    if text.isEmpty {
      return text
    }

    let rule: LanguageRule?
    if let lang = lang {
      guard let foundRule = getRuleByLang(lang) else {
        return text
      }
      rule = foundRule
    } else {
      rule = autoDetectRule(text.precomposedStringWithCanonicalMapping)
      if rule == nil {
        return text
      }
    }

    guard let rule = rule else {
      return text
    }

    let nfdText = text.decomposedStringWithCanonicalMapping

    var result: [String] = []
    var i = 0
    let chars = Array(nfdText)

    while i < chars.count {
      if !chars[i].isLetter {
        result.append(String(chars[i]))
        i += 1
        continue
      }

      let wordStart = i
      while i < chars.count && chars[i].isLetter {
        i += 1
      }

      let word = String(chars[wordStart..<i])
      let syllabifiedWord = WordSyllabifier(word: word, rule: rule, softHyphen: softHyphen)
        .syllabify()
      result.append(syllabifiedWord)
    }

    return result.joined().precomposedStringWithCanonicalMapping
  }
}
