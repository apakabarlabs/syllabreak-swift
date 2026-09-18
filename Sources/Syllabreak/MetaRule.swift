import Foundation

final class MetaRule: Sendable {
  let rules: [LanguageRule]

  init(rules: [LanguageRule]) {
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

    for rule in rules {
      var score = rule.calculateMatchScore(text)
      if score > 0 {
        let hasUniqueCharacter = cleanText.contains { rule.uniqueChars.contains($0) }
        if !rule.uniqueChars.isEmpty && hasUniqueCharacter {
          score = 1.0
        }
        matches.append((rule, score))
      }
    }

    matches.sort { $0.1 > $1.1 }

    return matches.map { $0.0 }
  }
}
