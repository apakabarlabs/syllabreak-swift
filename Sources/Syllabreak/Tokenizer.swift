import Foundation

class Tokenizer {
  private let wordScalars: [Unicode.Scalar]
  private let scalars: [Unicode.Scalar]
  private let rule: LanguageRule
  private var tokens: [Token] = []
  private var pos = 0

  private static let combiningDiaeresis: Unicode.Scalar = "\u{0308}"

  init(word: String, rule: LanguageRule) {
    let recomposed = Self.recomposeCategoryFlips(word, rule: rule)
    self.wordScalars = Array(recomposed.unicodeScalars)
    self.scalars = Array(recomposed.lowercased().unicodeScalars)
    self.rule = rule
  }

  private static func classifyLetter(_ char: Character, rule: LanguageRule) -> TokenClass? {
    if rule.vowelSet.contains(char) {
      return .vowel
    }
    if rule.consonantSet.contains(char) {
      return .consonant
    }
    return nil
  }

  /// Recompose base+combining-mark runs that NFC into a single declared
  /// letter whose category differs from the bare NFD base. Russian й = и
  /// (vowel) + combining breve composes back to the consonant й; left
  /// decomposed, the vowel base и is wrongly read as a syllable nucleus
  /// (мой -> мо-й) or absorbed into a long-vowel digraph (Kyrgyz ии: кийиз
  /// -> кийиз). Greek accented vowels (same class) and Montenegrin с́ (no
  /// precomposed form) are untouched.
  private static func recomposeCategoryFlips(_ word: String, rule: LanguageRule) -> String {
    let scalars = Array(word.unicodeScalars)
    var result = String.UnicodeScalarView()
    var i = 0
    while i < scalars.count {
      var end = i + 1
      while end < scalars.count && isNonspacingMark(scalars[end]) {
        end += 1
      }
      if end > i + 1 {
        let composed = String(String.UnicodeScalarView(scalars[i..<end]))
          .precomposedStringWithCanonicalMapping
        if composed.unicodeScalars.count == 1 {
          let baseClass = classifyLetter(Character(String(scalars[i]).lowercased()), rule: rule)
          let composedClass = classifyLetter(Character(composed.lowercased()), rule: rule)
          if composedClass != nil && composedClass != baseClass {
            result.append(contentsOf: composed.unicodeScalars)
            i = end
            continue
          }
        }
      }
      result.append(scalars[i])
      i += 1
    }
    return String(result)
  }

  func tokenize() -> [Token] {
    while pos < scalars.count {
      if tryMatchLeftModifier() {
        continue
      }
      if tryMatchSeparator() {
        continue
      }
      if tryMatchConsonantDigraph() {
        continue
      }
      if tryMatchVowelDigraph() {
        continue
      }
      addSingleCharacterToken()
    }
    return tokens
  }

  private func surface(start: Int, end: Int) -> String {
    String(String.UnicodeScalarView(wordScalars[start..<end]))
  }

  private func charAtLower(_ index: Int) -> Character {
    Character(scalars[index])
  }

  private static func isNonspacingMark(_ scalar: Unicode.Scalar) -> Bool {
    scalar.properties.generalCategory == .nonspacingMark
  }

  private func tryMatchLeftModifier() -> Bool {
    let scalar = scalars[pos]
    let char = Character(scalar)
    let attaches = rule.modifiersAttachLeftSet.contains(char) || Self.isNonspacingMark(scalar)
    if !attaches {
      return false
    }

    if !tokens.isEmpty {
      tokens[tokens.count - 1].surface += surface(start: pos, end: pos + 1)
      tokens[tokens.count - 1].endIdx = pos + 1
      tokens[tokens.count - 1].isModifier = true
    } else {
      tokens.append(
        Token(
          surface: surface(start: pos, end: pos + 1),
          tokenClass: .other,
          isModifier: true,
          startIdx: pos,
          endIdx: pos + 1
        )
      )
    }
    pos += 1
    return true
  }

  private func tryMatchSeparator() -> Bool {
    let char = charAtLower(pos)
    if !rule.modifiersSeparatorsSet.contains(char) {
      return false
    }

    tokens.append(
      Token(
        surface: surface(start: pos, end: pos + 1),
        tokenClass: .separator,
        startIdx: pos,
        endIdx: pos + 1
      )
    )
    pos += 1
    return true
  }

  private func tryMatchConsonantDigraph() -> Bool {
    tryMatchDigraph(source: rule.dontSplitDigraphsSet, tokenClass: .consonant)
  }

  private func tryMatchVowelDigraph() -> Bool {
    tryMatchDigraph(source: rule.digraphVowelsSet, tokenClass: .vowel)
  }

  private func tryMatchDigraph(source: Set<String>, tokenClass: TokenClass) -> Bool {
    // For each candidate length (3, 2, 1) try the Mn-skipping match
    // first, then the direct substring match. The Mn-skip path
    // composes the next N base letters skipping combining marks, so
    // it can cover more codepoints than a direct length-N substring
    // — necessary for Vietnamese triphthongs like yêu (y + ê + u),
    // where Mn-skip-3 matches the "yeu" base entry across 4
    // codepoints, while direct-3 would catch the shorter "ye◌̂"
    // first.
    //
    // The direct path is kept as a fallback within each length for
    // entries whose marks sit on a vowel that participates in the
    // digraph itself (German "üh" = u + ◌̈ + h).
    let positions = scanBases()
    let bases = positions.isEmpty ? [] : basesAtPositions(positions)
    for length in [3, 2, 1] {
      if bases.count >= length {
        let candidate = bases.prefix(length).map(String.init).joined()
        if source.contains(candidate) {
          let end = positions[length - 1]
          if !diaeresisVetoesAt(end) {
            addDigraphToken(end: end, tokenClass: tokenClass)
            pos = end
            return true
          }
        }
      }
      let end = pos + length
      if end > scalars.count {
        continue
      }
      let substr = String(String.UnicodeScalarView(scalars[pos..<end]))
      if source.contains(substr) && !diaeresisVetoesAt(end) {
        addDigraphToken(end: end, tokenClass: tokenClass)
        pos = end
        return true
      }
    }
    return false
  }

  private func addDigraphToken(end: Int, tokenClass: TokenClass) {
    tokens.append(
      Token(
        surface: surface(start: pos, end: end),
        tokenClass: tokenClass,
        startIdx: pos,
        endIdx: end
      )
    )
  }

  private func scanBases() -> [Int] {
    var positions: [Int] = []
    var p = pos
    while p < scalars.count && positions.count < 3 {
      if Self.isNonspacingMark(scalars[p]) {
        p += 1
        continue
      }
      positions.append(p + 1)
      p += 1
    }
    return positions
  }

  private func basesAtPositions(_ positions: [Int]) -> [Character] {
    var chars: [Character] = []
    for (idx, end) in positions.enumerated() {
      let start = idx == 0 ? pos : positions[idx - 1]
      for q in stride(from: end - 1, through: start, by: -1)
      where !Self.isNonspacingMark(scalars[q]) {
        chars.append(Character(scalars[q]))
        break
      }
    }
    return chars
  }

  private func diaeresisVetoesAt(_ endPos: Int) -> Bool {
    for p in endPos..<scalars.count {
      let scalar = scalars[p]
      if !Self.isNonspacingMark(scalar) {
        return false
      }
      if scalar == Self.combiningDiaeresis {
        return true
      }
    }
    return false
  }

  private func addSingleCharacterToken() {
    let char = charAtLower(pos)
    let tokenClass = Self.classifyLetter(char, rule: rule)
    tokens.append(
      Token(
        surface: surface(start: pos, end: pos + 1),
        tokenClass: tokenClass ?? .other,
        startIdx: pos,
        endIdx: pos + 1
      )
    )
    pos += 1
  }
}
