import Foundation

struct LanguageRule: Codable, Sendable {
  let lang: String
  let vowels: String
  let consonants: String
  let clustersKeepNext: [String]?
  let trailingOnsets: [String]?
  let dontSplitDigraphs: [String]?
  let digraphVowels: [String]?
  let vowelGlides: String?
  let syllabicConsonants: String?
  let modifiersAttachLeft: String?
  let modifiersSeparators: String?
  let clustersOnlyAfterLong: [String]?
  let splitHiatus: Bool?
  let finalSemivowels: String?
  let finalSequencesKeep: [String]?
  let suffixesBreakVre: [String]?
  let suffixesKeepVre: [String]?
  let exceptions: [String: String]?
  let geminateDigraphs: [String: String]?

  struct GeminateSpan {
    let start: Int
    let length: Int
    let compactOriginal: String
  }

  private struct GeminateMatch {
    let length: Int
    let compact: String
    let expansion: String
  }

  var vowelSet: Set<Character> { Self.augmentChars(vowels) }
  var consonantSet: Set<Character> { Self.augmentChars(consonants) }
  var vowelGlideSet: Set<Character> { Self.augmentChars(vowelGlides ?? "") }
  var syllabicConsonantSet: Set<Character> { Self.augmentChars(syllabicConsonants ?? "") }
  var modifiersAttachLeftSet: Set<Character> { Self.augmentChars(modifiersAttachLeft ?? "") }
  var modifiersSeparatorsSet: Set<Character> { Self.augmentChars(modifiersSeparators ?? "") }
  var finalSemivowelsSet: Set<Character> { Self.augmentChars(finalSemivowels ?? "") }

  var clustersKeepNextSet: Set<String> { Self.augmentStrings(clustersKeepNext) }
  var trailingOnsetsSet: Set<String> { Self.augmentStrings(trailingOnsets) }
  var dontSplitDigraphsSet: Set<String> { Self.augmentStrings(dontSplitDigraphs) }
  var digraphVowelsSet: Set<String> { Self.augmentStrings(digraphVowels) }
  var clustersOnlyAfterLongSet: Set<String> { Self.augmentStrings(clustersOnlyAfterLong) }
  var finalSequencesKeepSet: Set<String> { Self.augmentStrings(finalSequencesKeep) }
  var suffixesBreakVreSet: Set<String> { Self.augmentStrings(suffixesBreakVre) }
  var suffixesKeepVreSet: Set<String> { Self.augmentStrings(suffixesKeepVre) }
  var exceptionMap: [String: String] { Self.augmentMapping(exceptions) }

  var allChars: Set<Character> {
    vowelSet.union(consonantSet)
  }

  private static func augmentChars(_ source: String) -> Set<Character> {
    var result = Set<Character>()
    for char in source {
      result.insert(char)
      for scalar in String(char).decomposedStringWithCanonicalMapping.unicodeScalars
      where scalar.properties.generalCategory != .nonspacingMark {
        result.insert(Character(scalar))
      }
    }
    return result
  }

  static func augmentStrings(_ source: [String]?) -> Set<String> {
    guard let entries = source else { return [] }
    var result = Set<String>(minimumCapacity: entries.count * 2)
    for entry in entries {
      result.insert(entry)
      result.insert(entry.decomposedStringWithCanonicalMapping)
    }
    return result
  }

  static func augmentMapping(_ source: [String: String]?) -> [String: String] {
    guard let entries = source else { return [:] }
    var result = entries
    for (key, value) in entries {
      result[key.decomposedStringWithCanonicalMapping] =
        value.decomposedStringWithCanonicalMapping
    }
    return result
  }

  var uniqueChars: Set<Character> = []

  private enum CodingKeys: String, CodingKey {
    case lang
    case vowels
    case consonants
    case clustersKeepNext = "clusters_keep_next"
    case trailingOnsets = "trailing_onsets"
    case dontSplitDigraphs = "dont_split_digraphs"
    case digraphVowels = "digraph_vowels"
    case vowelGlides = "vowel_glides"
    case syllabicConsonants = "syllabic_consonants"
    case modifiersAttachLeft = "modifiers_attach_left"
    case modifiersSeparators = "modifiers_separators"
    case clustersOnlyAfterLong = "clusters_only_after_long"
    case splitHiatus = "split_hiatus"
    case finalSemivowels = "final_semivowels"
    case finalSequencesKeep = "final_sequences_keep"
    case suffixesBreakVre = "suffixes_break_vre"
    case suffixesKeepVre = "suffixes_keep_vre"
    case exceptions
    case geminateDigraphs = "geminate_digraphs"
  }

  func isVowel(_ char: Character) -> Bool {
    return vowelSet.contains(char)
  }

  func isConsonant(_ char: Character) -> Bool {
    return consonantSet.contains(char)
  }

  func containsChar(_ char: Character) -> Bool {
    return allChars.contains(char)
  }

  func calculateMatchScore(_ text: String) -> Double {
    let cleanText = text.lowercased().filter { $0.isLetter }
    if cleanText.isEmpty {
      return 0.0
    }

    let matching = cleanText.filter { containsChar($0) }.count
    return Double(matching) / Double(cleanText.count)
  }

  func expandGeminateDigraphs(_ word: String) -> (String, [GeminateSpan]) {
    let geminates = Self.augmentMapping(geminateDigraphs)
    guard !geminates.isEmpty else {
      return (word, [])
    }
    // Iterate at Unicode scalar level so the resulting span positions
    // line up with what the Tokenizer (also scalar-based) sees.
    let wordScalars = Array(word.unicodeScalars)
    let lowerScalars = Array(word.lowercased().unicodeScalars)
    let patterns = geminates.sorted {
      Array($0.key.unicodeScalars).count > Array($1.key.unicodeScalars).count
    }
    var result = ""
    var spans: [GeminateSpan] = []
    var i = 0
    var expandedPos = 0
    while i < wordScalars.count {
      if let match = geminateMatch(
        at: i, wordScalars: wordScalars, lowerScalars: lowerScalars, patterns: patterns
      ) {
        let expansion = match.expansion
        let expansionLength = Array(expansion.unicodeScalars).count
        spans.append(
          GeminateSpan(
            start: expandedPos,
            length: expansionLength,
            compactOriginal: match.compact
          )
        )
        result += expansion
        expandedPos += expansionLength
        i += match.length
      } else {
        result.append(Character(wordScalars[i]))
        expandedPos += 1
        i += 1
      }
    }
    return (result, spans)
  }

  private func geminateMatch(
    at index: Int,
    wordScalars: [Unicode.Scalar],
    lowerScalars: [Unicode.Scalar],
    patterns: [(key: String, value: String)]
  ) -> GeminateMatch? {
    for (short, long) in patterns {
      let length = short.unicodeScalars.count
      guard index + length <= wordScalars.count else { continue }
      let range = index..<(index + length)
      let candidate = String(String.UnicodeScalarView(lowerScalars[range]))
      guard candidate == short else { continue }

      let compact = String(String.UnicodeScalarView(wordScalars[range]))
      let expansion: String
      if compact == compact.uppercased() {
        expansion = long.uppercased()
      } else if compact.first?.isUppercase == true {
        expansion = long.prefix(1).uppercased() + long.dropFirst().lowercased()
      } else {
        expansion = long
      }
      return GeminateMatch(length: length, compact: compact, expansion: expansion)
    }
    return nil
  }
}
