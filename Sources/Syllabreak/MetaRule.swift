import Foundation

final class MetaRule: Sendable {
  let rules: [LanguageRule]

  init(rules: [LanguageRule]) {
    // Calculate unique chars before storing
    var mutableRules = rules
    for i in 0..<mutableRules.count {
      var uniqueChars = mutableRules[i].allChars
      for j in 0..<mutableRules.count where i != j {
        uniqueChars.subtract(mutableRules[j].allChars)
      }
      mutableRules[i].uniqueChars = uniqueChars
    }
    self.rules = mutableRules
  }

  func getAllKnownChars() -> Set<Character> {
    var allChars = Set<Character>()
    for rule in rules {
      allChars.formUnion(rule.allChars)
    }
    return allChars
  }

  func findMatches(_ text: String) -> [LanguageRule] {
    if text.isEmpty {
      return []
    }

    let cleanText = text.lowercased().filter { $0.isLetter }
    if cleanText.isEmpty {
      return []
    }

    var matches: [(LanguageRule, Double)] = []

    // Calculate scores for all rules
    for rule in rules {
      var score = rule.calculateMatchScore(text)
      if score > 0 {
        // Boost score if has unique characters
        if !rule.uniqueChars.isEmpty && cleanText.contains(where: { rule.uniqueChars.contains($0) })
        {
          score = 1.0  // Maximum score for unique chars
        }
        matches.append((rule, score))
      }
    }

    // Sort by score descending
    matches.sort { $0.1 > $1.1 }

    return matches.map { $0.0 }
  }
}
