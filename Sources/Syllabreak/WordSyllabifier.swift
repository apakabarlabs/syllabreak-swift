import Foundation

class WordSyllabifier {
  let originalWord: String
  let word: String
  let geminateSpans: [LanguageRule.GeminateSpan]
  let rule: LanguageRule
  let softHyphen: String
  let tokens: [Token]
  lazy var nuclei: [Int] = NucleusFinder(word: word, tokens: tokens, rule: rule).find()

  init(word: String, rule: LanguageRule, softHyphen: String) {
    self.originalWord = word
    let (expanded, spans) = rule.expandGeminateDigraphs(word)
    self.word = expanded
    self.geminateSpans = spans
    self.rule = rule
    self.softHyphen = softHyphen
    let rawTokens = WordSyllabifier.tokenize(word: expanded, rule: rule)
    self.tokens = WordSyllabifier.reclassifyVowelGlides(tokens: rawTokens, rule: rule)
  }

  private static func tokenize(word: String, rule: LanguageRule) -> [Token] {
    let tokenizer = Tokenizer(word: word, rule: rule)
    return tokenizer.tokenize()
  }

  private static func reclassifyVowelGlides(tokens: [Token], rule: LanguageRule) -> [Token] {
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

    if rule.clustersOnlyAfterLongSet.contains(onsetCandidate), let prevIdx = prevNucleusIdx {
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
    guard nucleusIdx < tokens.count else { return false }

    let vowelToken = tokens[nucleusIdx]

    if rule.digraphVowelsSet.contains(vowelToken.surface.lowercased()) {
      return true
    }

    if nucleusIdx + 1 < tokens.count {
      let nextToken = tokens[nucleusIdx + 1]
      let digraph = vowelToken.surface.lowercased() + nextToken.surface.lowercased()
      if rule.digraphVowelsSet.contains(digraph) {
        return true
      }
    }

    return false
  }

  private func findBoundaryForSingleConsonant(_ clusterIndices: [Int], nk: Int, nk1: Int) -> Int? {
    let consonantIdx = clusterIndices[0]

    if !rule.finalSequencesKeepSet.isEmpty {
      let sequence = tokens[nk...nk1].map { $0.surface.lowercased() }.joined()

      if rule.finalSequencesKeepSet.contains(sequence) {
        let restWithVowel = tokens[nk1...].map { $0.surface.lowercased() }.joined()
        let restAfterVowel =
          nk1 + 1 < tokens.count
          ? tokens[(nk1 + 1)...].map { $0.surface.lowercased() }.joined()
          : ""

        if !rule.suffixesBreakVreSet.isEmpty {
          for suffix in rule.suffixesBreakVreSet {
            if restWithVowel == suffix || restWithVowel.hasPrefix(suffix) {
              return nk1
            }
          }
        }

        let isAtEnd = nk1 == tokens.count - 1
        var hasLightSuffix = false
        if !rule.suffixesKeepVreSet.isEmpty && !restAfterVowel.isEmpty {
          hasLightSuffix = rule.suffixesKeepVreSet.contains(restAfterVowel)
        }

        if isAtEnd || hasLightSuffix {
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
    if cluster.count >= 3 {
      let onset3 =
        (cluster[cluster.count - 3].surface + cluster[cluster.count - 2].surface
        + cluster[cluster.count - 1].surface).lowercased()
      if rule.clustersKeepNextSet.contains(onset3) || rule.trailingOnsetsSet.contains(onset3) {
        return clusterIndices[clusterIndices.count - 3]
      }
    }

    var boundaryIdx = clusterIndices[clusterIndices.count - 1]
    let lastTwoFormValidOnset =
      cluster.count >= 2
      && isValidOnset(
        cluster[cluster.count - 2].surface,
        cluster[cluster.count - 1].surface,
        prevNucleusIdx: prevNucleusIdx,
        includeTrailingOnsets: true
      )
    if lastTwoFormValidOnset {
      boundaryIdx = clusterIndices[clusterIndices.count - 2]
    }

    return boundaryIdx
  }

  private func findBoundaryInCluster(
    _ cluster: [Token], _ clusterIndices: [Int], _ nk: Int, _ nk1: Int
  ) -> Int? {
    if cluster.isEmpty {
      guard rule.splitHiatus == true else {
        return nil
      }

      var areAdjacent = nk1 - nk == 1
      if !areAdjacent {
        var allSeparators = true
        for i in (nk + 1)..<nk1 where tokens[i].tokenClass != .separator {
          allSeparators = false
          break
        }
        areAdjacent = allSeparators
      }

      if areAdjacent {
        let vowelPair = tokens[nk].surface.lowercased() + tokens[nk1].surface.lowercased()
        if rule.digraphVowelsSet.contains(vowelPair) {
          return nil
        }
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
    if let exceptionSplit = rule.exceptionMap[originalWord.lowercased()] {
      return applyException(exceptionSplit)
    }

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
