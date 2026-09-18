import Foundation

class WordSyllabifier {
  let originalWord: String
  let word: String
  let geminateSpans: [LanguageRule.GeminateSpan]
  let rule: LanguageRule
  let softHyphen: String
  let tokens: [Token]
  let nuclei: [Int]

  init(word: String, rule: LanguageRule, softHyphen: String) {
    self.originalWord = word
    let (expanded, spans) = rule.expandGeminateDigraphs(word)
    self.word = expanded
    self.geminateSpans = spans
    self.rule = rule
    self.softHyphen = softHyphen
    let rawTokens = WordSyllabifier.tokenize(word: expanded, rule: rule)
    self.tokens = WordSyllabifier.reclassifyVowelGlides(tokens: rawTokens, rule: rule)
    self.nuclei = WordSyllabifier.findNuclei(tokens: tokens, rule: rule)
  }

  private static func tokenize(word: String, rule: LanguageRule) -> [Token] {
    let tokenizer = Tokenizer(word: word, rule: rule)
    return tokenizer.tokenize()
  }

  private static func reclassifyVowelGlides(tokens: [Token], rule: LanguageRule) -> [Token] {
    // Kazakh у/и are a syllable nucleus after a consonant (ту-ыс, ки-ім,
    // су-лу) but a glide consonant after a vowel (да-уа, not да-у-а; а-уа).
    // Retag a single vowel-glide token to consonant when the previous
    // non-separator token is a vowel. Long-vowel digraphs (Kyrgyz уу/ии)
    // tokenise as one multi-character VOWEL token and are left untouched.
    let vowelGlides = rule.vowelGlideSet
    if vowelGlides.isEmpty {
      return tokens
    }
    var result = tokens
    for i in result.indices where result[i].tokenClass == .vowel {
      let lower = result[i].surface.lowercased()
      guard lower.count == 1, let ch = lower.first, vowelGlides.contains(ch) else { continue }
      var prev = i - 1
      while prev >= 0 && result[prev].tokenClass == .separator {
        prev -= 1
      }
      if prev >= 0 && result[prev].tokenClass == .vowel {
        result[i].tokenClass = .consonant
      }
    }
    return result
  }

  private static func findNuclei(tokens: [Token], rule: LanguageRule) -> [Int] {
    var nuclei = findVowelNuclei(tokens: tokens)
    nuclei = removeFinalSemivowels(tokens: tokens, nuclei: nuclei, rule: rule)
    nuclei = addSyllabicConsonants(tokens: tokens, nuclei: nuclei, rule: rule)

    if !nuclei.isEmpty {
      return nuclei
    }

    // Fallback: if no vowels at all, try syllabic consonants anywhere
    return findFallbackSyllabicConsonants(tokens: tokens, rule: rule)
  }

  private static func findVowelNuclei(tokens: [Token]) -> [Int] {
    var nuclei: [Int] = []
    for (i, token) in tokens.enumerated() where token.tokenClass == .vowel {
      nuclei.append(i)
    }
    return nuclei
  }

  private static func removeFinalSemivowels(tokens: [Token], nuclei: [Int], rule: LanguageRule)
    -> [Int]
  {
    var nuclei = nuclei
    guard !nuclei.isEmpty && !rule.finalSemivowelsSet.isEmpty else { return nuclei }

    let lastNucleusIdx = nuclei[nuclei.count - 1]
    let lastToken = tokens[lastNucleusIdx]

    let isFinal = (lastNucleusIdx + 1..<tokens.count).allSatisfy {
      tokens[$0].tokenClass == .separator || tokens[$0].tokenClass == .other
    }

    guard isFinal,
      let firstChar = lastToken.surface.lowercased().first,
      rule.finalSemivowelsSet.contains(firstChar),
      lastNucleusIdx > 0,
      tokens[lastNucleusIdx - 1].tokenClass == .consonant
    else { return nuclei }

    nuclei.removeLast()
    return nuclei
  }

  private static func addSyllabicConsonants(tokens: [Token], nuclei: [Int], rule: LanguageRule)
    -> [Int]
  {
    guard !rule.syllabicConsonantSet.isEmpty && !nuclei.isEmpty else { return nuclei }

    var syllabicNuclei: [Int] = []
    for (i, token) in tokens.enumerated() {
      guard token.tokenClass == .consonant,
        token.surface.count == 1,
        let char = token.surface.lowercased().first,
        rule.syllabicConsonantSet.contains(char),
        isSurroundedByConsonants(tokens: tokens, index: i),
        hasBufferToVowels(tokens: tokens, index: i)
      else { continue }
      syllabicNuclei.append(i)
    }

    guard !syllabicNuclei.isEmpty else { return nuclei }
    return (Set(nuclei).union(Set(syllabicNuclei))).sorted()
  }

  private static func isSurroundedByConsonants(tokens: [Token], index: Int) -> Bool {
    let prevIsConsonant = (index == 0) || (tokens[index - 1].tokenClass == .consonant)
    let nextIsConsonant =
      (index == tokens.count - 1) || (tokens[index + 1].tokenClass == .consonant)
    return prevIsConsonant && nextIsConsonant
  }

  private static func hasBufferToVowels(tokens: [Token], index: Int) -> Bool {
    // "No vowel at all on this side" (a word-initial or word-final
    // run of consonants) counts as the buffer being satisfied —
    // Swahili m-toto, BCMS prst/vrh.
    var distToPrevVowel: Int? = nil
    for j in stride(from: index - 1, through: 0, by: -1) where tokens[j].tokenClass == .vowel {
      distToPrevVowel = index - j
      break
    }

    var distToNextVowel: Int? = nil
    for j in (index + 1)..<tokens.count where tokens[j].tokenClass == .vowel {
      distToNextVowel = j - index
      break
    }

    let hasBufferBefore = distToPrevVowel.map { $0 > 1 } ?? true
    let hasBufferAfter = distToNextVowel.map { $0 > 1 } ?? true
    return hasBufferBefore && hasBufferAfter
  }

  private static func findFallbackSyllabicConsonants(tokens: [Token], rule: LanguageRule) -> [Int] {
    var nuclei: [Int] = []
    for (i, token) in tokens.enumerated() {
      guard token.tokenClass == .consonant,
        token.surface.count == 1,
        let char = token.surface.lowercased().first,
        rule.syllabicConsonantSet.contains(char)
      else { continue }
      nuclei.append(i)
    }
    return nuclei
  }

  private func skipSeparatorsForward(_ start: Int) -> Int {
    var pos = start
    while pos < tokens.count && tokens[pos].tokenClass == .separator {
      pos += 1
    }
    return pos
  }

  private func skipSeparatorsBackward(_ start: Int) -> Int {
    var pos = start
    while pos >= 0 && tokens[pos].tokenClass == .separator {
      pos -= 1
    }
    return pos
  }

  private func extractConsonantCluster(left: Int, right: Int) -> ([Token], [Int]) {
    var cluster: [Token] = []
    var clusterIndices: [Int] = []

    for i in left...right {
      if i < tokens.count && tokens[i].tokenClass == .consonant {
        cluster.append(tokens[i])
        clusterIndices.append(i)
      }
    }

    return (cluster, clusterIndices)
  }

  private func findClusterBetweenNuclei(nk: Int, nk1: Int) -> ([Token], [Int]) {
    let left = skipSeparatorsForward(nk + 1)
    let right = skipSeparatorsBackward(nk1 - 1)

    if left > right {
      return ([], [])
    }

    return extractConsonantCluster(left: left, right: right)
  }

  private func findSeparatorBetween(nk: Int, nk1: Int) -> Int? {
    // A separator (Russian hard sign ъ) marks a morpheme boundary: the
    // preceding consonant is the coda of the previous syllable and the
    // separator + iotated vowel open the next one (об-ъект, под-ъезд,
    // из-ъян). The boundary falls on the separator itself, overriding the
    // usual onset-cluster rule that would move the lone consonant to the
    // next syllable (о-бъект).
    for i in (nk + 1)..<nk1 where tokens[i].tokenClass == .separator {
      return i
    }
    return nil
  }

  private func isValidOnset(
    _ consonant1: String,
    _ consonant2: String,
    prevNucleusIdx: Int? = nil,
    includeTrailingOnsets: Bool = false
  ) -> Bool {
    let onsetCandidate = consonant1.lowercased() + consonant2.lowercased()

    // Check if this cluster requires a long vowel before it
    if rule.clustersOnlyAfterLongSet.contains(onsetCandidate), let prevIdx = prevNucleusIdx {
      // Check if previous nucleus is long (digraph or marked as long)
      if !isLongNucleus(prevIdx) {
        return false
      }
    }

    if rule.clustersKeepNextSet.contains(onsetCandidate) {
      return true
    }
    if includeTrailingOnsets && rule.trailingOnsetsSet.contains(onsetCandidate) {
      return true
    }
    return false
  }

  private func isLongNucleus(_ nucleusIdx: Int) -> Bool {
    // Check if nucleus at given index is long (digraph vowel or followed by lengthening marker)
    guard nucleusIdx < tokens.count else { return false }

    let vowelToken = tokens[nucleusIdx]

    // Check if this vowel token itself is already a digraph (tokenized as one unit)
    if rule.digraphVowelsSet.contains(vowelToken.surface.lowercased()) {
      return true
    }

    // Check if current vowel + next character forms a digraph vowel
    if nucleusIdx + 1 < tokens.count {
      let nextToken = tokens[nucleusIdx + 1]
      let digraph = vowelToken.surface.lowercased() + nextToken.surface.lowercased()
      if rule.digraphVowelsSet.contains(digraph) {
        return true
      }
    }

    // Single vowel is considered short
    return false
  }

  private func findBoundaryForSingleConsonant(_ clusterIndices: [Int], nk: Int, nk1: Int) -> Int? {
    // V-CV: boundary before single consonant
    //
    // Exception: Don't split V-r-e patterns (care, here, more) when:
    // - At word end, OR
    // - Before light suffixes (-s, -less, -ful, -ly, -ing, -ed)
    //
    // But split AFTER the consonant when followed by breaking suffixes (-ent, -ence, -ency, -ment):
    // - parent -> par-ent, adherent -> ad-her-ent

    let consonantIdx = clusterIndices[0]

    // Check for protected sequences (like -are, -ere, -ore, -ure, -ire)
    if !rule.finalSequencesKeepSet.isEmpty {
      // Build the sequence from current vowel nucleus through next nucleus
      let sequence = tokens[nk...nk1].map { $0.surface.lowercased() }.joined()

      if rule.finalSequencesKeepSet.contains(sequence) {
        // Get the rest of the word starting from next nucleus (includes the vowel)
        let restWithVowel = tokens[nk1...].map { $0.surface.lowercased() }.joined()
        let restAfterVowel =
          nk1 + 1 < tokens.count
          ? tokens[(nk1 + 1)...].map { $0.surface.lowercased() }.joined()
          : ""

        // Check if followed by a breaking suffix (par-ent, ad-her-ent)
        // The suffix starts from the next vowel: "ent" in "par-ent"
        if !rule.suffixesBreakVreSet.isEmpty {
          for suffix in rule.suffixesBreakVreSet {
            if restWithVowel == suffix || restWithVowel.hasPrefix(suffix) {
              // Split after consonant = before next nucleus
              return nk1
            }
          }
        }

        // Check if at word end or followed by light suffix (care, care-less)
        let isAtEnd = nk1 == tokens.count - 1
        var hasLightSuffix = false
        if !rule.suffixesKeepVreSet.isEmpty && !restAfterVowel.isEmpty {
          hasLightSuffix = rule.suffixesKeepVreSet.contains(restAfterVowel)
        }

        if isAtEnd || hasLightSuffix {
          // Don't split - return nil to indicate no boundary
          return nil
        }
      }
    }

    return consonantIdx
  }

  private func findBoundaryForTwoConsonants(
    _ cluster: [Token],
    _ clusterIndices: [Int],
    prevNucleusIdx: Int? = nil
  ) -> Int {
    // Determine boundary for two-consonant cluster
    if isValidOnset(cluster[0].surface, cluster[1].surface, prevNucleusIdx: prevNucleusIdx) {
      return clusterIndices[0]
    } else {
      return clusterIndices[1]
    }
  }

  private func findBoundaryForLongCluster(
    _ cluster: [Token],
    _ clusterIndices: [Int],
    prevNucleusIdx: Int? = nil
  ) -> Int {
    // Determine boundary for cluster with 3+ consonants. Try the last
    // THREE consonants as a single onset first (Greek στρ in ά-στρο);
    // fall back to the 2-letter check.
    if cluster.count >= 3 {
      let onset3 =
        (cluster[cluster.count - 3].surface + cluster[cluster.count - 2].surface
        + cluster[cluster.count - 1].surface).lowercased()
      if rule.clustersKeepNextSet.contains(onset3) || rule.trailingOnsetsSet.contains(onset3) {
        return clusterIndices[clusterIndices.count - 3]
      }
    }

    var boundaryIdx = clusterIndices[clusterIndices.count - 1]
    if cluster.count >= 2
      && isValidOnset(
        cluster[cluster.count - 2].surface,
        cluster[cluster.count - 1].surface,
        prevNucleusIdx: prevNucleusIdx,
        includeTrailingOnsets: true
      )
    {
      boundaryIdx = clusterIndices[clusterIndices.count - 2]
    }

    return boundaryIdx
  }

  private func findBoundaryInCluster(
    _ cluster: [Token], _ clusterIndices: [Int], _ nk: Int, _ nk1: Int
  ) -> Int? {
    // Determine where to place boundary in a consonant cluster or between vowels
    if cluster.isEmpty {
      // Check for vowel hiatus (adjacent vowels that form separate syllables)
      guard rule.splitHiatus == true else {
        return nil
      }

      // Check if nuclei are adjacent (or only separated by modifiers/separators)
      var areAdjacent = nk1 - nk == 1
      if !areAdjacent {
        // Check if there are only separators between vowels
        var allSeparators = true
        for i in (nk + 1)..<nk1 where tokens[i].tokenClass != .separator {
          allSeparators = false
          break
        }
        areAdjacent = allSeparators
      }

      if areAdjacent {
        // Check if these two vowels form a digraph (don't split)
        let vowelPair = tokens[nk].surface.lowercased() + tokens[nk1].surface.lowercased()
        if rule.digraphVowelsSet.contains(vowelPair) {
          return nil
        }
        // Hiatus: split between vowels
        return nk1
      }
      return nil
    } else if cluster.count == 1 {
      return findBoundaryForSingleConsonant(clusterIndices, nk: nk, nk1: nk1)
    } else if cluster.count == 2 {
      return findBoundaryForTwoConsonants(cluster, clusterIndices, prevNucleusIdx: nk)
    } else {
      return findBoundaryForLongCluster(cluster, clusterIndices, prevNucleusIdx: nk)
    }
  }

  private func placeBoundaries() -> [Int] {
    // Determine syllable boundaries between nuclei
    var boundaries: [Int] = []

    for k in 0..<(nuclei.count - 1) {
      if let separatorIdx = findSeparatorBetween(nk: nuclei[k], nk1: nuclei[k + 1]) {
        boundaries.append(separatorIdx)
        continue
      }
      let (cluster, clusterIndices) = findClusterBetweenNuclei(nk: nuclei[k], nk1: nuclei[k + 1])
      if let boundary = findBoundaryInCluster(cluster, clusterIndices, nuclei[k], nuclei[k + 1]) {
        boundaries.append(boundary)
      }
    }

    return boundaries
  }

  func syllabify() -> String {
    if let exceptionSplit = rule.exceptions?[originalWord.lowercased()] {
      return applyException(exceptionSplit)
    }

    // When the word doesn't actually split, hand back the original surface
    // so any geminate-digraph expansion isn't visible to the caller.
    if nuclei.count < 2 {
      return originalWord
    }

    let boundaries = placeBoundaries()
    if boundaries.isEmpty {
      return originalWord
    }

    return renderWithGeminateSpans(boundaries: boundaries)
  }
}
