import Foundation

struct LanguageRule: Codable, Sendable {
  let lang: String
  let vowels: String
  let consonants: String
  let clustersKeepNext: [String]?
  // trailing_onsets — onsets valid ONLY in trailing position of a 3+
  // consonant cluster. Used for Dutch where s+stop splits as VC-CV in
  // a plain 2-cons cluster (kas-teel) but stays together as the next
  // syllable's onset when preceded by another consonant (ven-ster,
  // in-dus-trie). Checked alongside clustersKeepNext inside the 3+
  // cluster boundary decision.
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
  // Lowercased word -> hyphen-marked split. Overrides the algorithm for
  // individual words that escape the general rules (e.g. BCMS "dvije",
  // "prije" — graphic -ije- not from jat, see Matešić 2015 rule P11).
  let exceptions: [String: String]?
  // Compact-form digraph geminates -> expanded form, applied before
  // tokenisation. Hungarian writes long double digraphs in a simplified
  // form (ssz=sz+sz, ggy=gy+gy, ...) but at a line break both halves
  // are restored in full (asz-szony, meny-nyi).
  let geminateDigraphs: [String: String]?

  struct GeminateSpan {
    let start: Int
    let length: Int
    let compactOriginal: String
  }

  // Character sets are augmented with the NFD base of each precomposed
  // letter (combining marks filtered out). This lets a NFD-normalised
  // input — what the tokenizer sees inside syllabify() — match against
  // the base letter that the YAML lists in precomposed form.
  var vowelSet: Set<Character> { Self.augmentChars(vowels) }
  var consonantSet: Set<Character> { Self.augmentChars(consonants) }
  var vowelGlideSet: Set<Character> { Self.augmentChars(vowelGlides ?? "") }
  var syllabicConsonantSet: Set<Character> { Self.augmentChars(syllabicConsonants ?? "") }
  var modifiersAttachLeftSet: Set<Character> { Self.augmentChars(modifiersAttachLeft ?? "") }
  var modifiersSeparatorsSet: Set<Character> { Self.augmentChars(modifiersSeparators ?? "") }
  var finalSemivowelsSet: Set<Character> { Self.augmentChars(finalSemivowels ?? "") }

  // Multi-character entries are augmented with their full NFD decomposition,
  // so entries with precomposed letters (deu "üh", grc "αἰ") still match
  // when input has been NFD-normalised.
  var clustersKeepNextSet: Set<String> { Self.augmentStrings(clustersKeepNext) }
  var trailingOnsetsSet: Set<String> { Self.augmentStrings(trailingOnsets) }
  var dontSplitDigraphsSet: Set<String> { Self.augmentStrings(dontSplitDigraphs) }
  var digraphVowelsSet: Set<String> { Self.augmentStrings(digraphVowels) }
  var clustersOnlyAfterLongSet: Set<String> { Self.augmentStrings(clustersOnlyAfterLong) }
  var finalSequencesKeepSet: Set<String> { Self.augmentStrings(finalSequencesKeep) }
  var suffixesBreakVreSet: Set<String> { Self.augmentStrings(suffixesBreakVre) }
  var suffixesKeepVreSet: Set<String> { Self.augmentStrings(suffixesKeepVre) }

  var allChars: Set<Character> {
    vowelSet.union(consonantSet)
  }

  private static func augmentChars(_ source: String) -> Set<Character> {
    var result = Set<Character>()
    for char in source {
      result.insert(char)
      // NFD decomposition: keep the base letter, drop combining marks
      // — those are handled by the tokenizer's Mn auto-attach.
      for scalar in String(char).decomposedStringWithCanonicalMapping.unicodeScalars
      where scalar.properties.generalCategory != .nonspacingMark {
        result.insert(Character(scalar))
      }
    }
    return result
  }

  private static func augmentStrings(_ source: [String]?) -> Set<String> {
    guard let entries = source else { return [] }
    var result = Set<String>(minimumCapacity: entries.count * 2)
    for entry in entries {
      result.insert(entry)
      result.insert(entry.decomposedStringWithCanonicalMapping)
    }
    return result
  }

  // Additional property for unique chars (will be set by MetaRule)
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

  /// Expand compact-form digraph geminates (Hungarian ssz, ggy, ...).
  /// Returns the expanded string and a list of spans. Each span carries
  /// (start_in_expanded, length_in_expanded, compact_original_text) so the
  /// renderer can decide whether to keep the expanded form (when a boundary
  /// falls inside) or restore the compact form (when it doesn't).
  func expandGeminateDigraphs(_ word: String) -> (String, [GeminateSpan]) {
    guard let geminates = geminateDigraphs, !geminates.isEmpty else {
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
      var matched = false
      for (short, long) in patterns {
        let shortScalars = Array(short.unicodeScalars)
        let shortLen = shortScalars.count
        if i + shortLen > wordScalars.count { continue }
        let candidate = String(String.UnicodeScalarView(lowerScalars[i..<(i + shortLen)]))
        if candidate != short { continue }
        let originalCompact = String(String.UnicodeScalarView(wordScalars[i..<(i + shortLen)]))
        let expansion: String
        if originalCompact == originalCompact.uppercased() {
          expansion = long.uppercased()
        } else if originalCompact.first?.isUppercase == true {
          let head = long.prefix(1).uppercased()
          let tail = long.dropFirst().lowercased()
          expansion = head + tail
        } else {
          expansion = long
        }
        let expansionLength = Array(expansion.unicodeScalars).count
        spans.append(
          GeminateSpan(
            start: expandedPos,
            length: expansionLength,
            compactOriginal: originalCompact
          )
        )
        result += expansion
        expandedPos += expansionLength
        i += shortLen
        matched = true
        break
      }
      if !matched {
        result.append(Character(wordScalars[i]))
        expandedPos += 1
        i += 1
      }
    }
    return (result, spans)
  }
}
