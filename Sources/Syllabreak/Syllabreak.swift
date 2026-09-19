import Foundation
import SwiftEmbed

public final class Syllabreak: Sendable {
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

  public init(softHyphen: String = defaultSoftHyphen) {
    self.softHyphen = softHyphen
    self.metaRule = MetaRule(rules: Self.rulesData.rules)
  }

  /// Returns matching language codes in descending confidence order.
  ///
  /// Canonically equivalent NFC and NFD input produces the same result.
  public func detectLanguage(_ text: String) -> [String] {
    let matchingRules = metaRule.findMatches(text.precomposedStringWithCanonicalMapping)
    return matchingRules.map { $0.lang }
  }

  /// Codes of every language the loaded rules cover, in rule-file order.
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

  /// Inserts soft hyphens at valid syllable boundaries.
  ///
  /// When `lang` is `nil`, the language is detected automatically. The input is returned unchanged
  /// when no rule matches or when the requested language is unsupported. The result is NFC-normalized.
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
