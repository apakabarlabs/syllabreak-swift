struct NucleusFinder {
  let word: String
  let tokens: [Token]
  let rule: LanguageRule

  func find() -> [Int] {
    var nuclei = vowelNuclei()
    nuclei = removingFinalSemivowels(from: nuclei)
    nuclei = addingSyllabicConsonants(to: nuclei)
    return nuclei.isEmpty ? fallbackSyllabicConsonants() : nuclei
  }

  private func vowelNuclei() -> [Int] {
    let silentNucleus = classifiedNucleus()
    return tokens.indices.filter {
      tokens[$0].tokenClass == .vowel
        && !(silentNucleus?.index == $0 && silentNucleus?.outcome == "silent")
    }
  }

  private func classifiedNucleus() -> (index: Int, outcome: String)? {
    let wordScalars = Array(word.lowercased().unicodeScalars)
    let lowerWord = word.lowercased()
    for suffixRule in rule.validatedVowelNucleusRules {
      if let words = suffixRule.words, !words.contains(lowerWord) { continue }
      let endingScalars = Array(
        suffixRule.suffix.decomposedStringWithCanonicalMapping.unicodeScalars)
      guard wordScalars.count >= endingScalars.count,
        wordScalars.suffix(endingScalars.count).elementsEqual(endingScalars)
      else { continue }
      let endingStart = wordScalars.count - endingScalars.count
      let predecessors = Set(
        (suffixRule.precededBy ?? []).flatMap {
          $0.decomposedStringWithCanonicalMapping.unicodeScalars
        }
      )
      var preceding = endingStart - 1
      while preceding >= 0 && wordScalars[preceding].properties.generalCategory == .nonspacingMark {
        preceding -= 1
      }
      let predecessorDoesNotMatch =
        preceding < 0 || !predecessors.contains(wordScalars[preceding])
      if !predecessors.isEmpty && predecessorDoesNotMatch {
        continue
      }
      if let predecessorClass = suffixRule.precededByClass {
        guard preceding >= 0 else { continue }
        let predecessor = Character(wordScalars[preceding])
        let expected = predecessorClass == "consonant" ? rule.consonantSet : rule.vowelSet
        if !expected.contains(predecessor) { continue }
      }
      let target = endingStart + suffixRule.vowelOffset
      let vowelLength = suffixRule.vowelLength ?? 1
      if let index = tokens.indices.first(where: {
        tokens[$0].startIdx == target && tokens[$0].endIdx == target + vowelLength
          && tokens[$0].tokenClass == .vowel
      }) {
        return (index, suffixRule.outcome)
      }
    }
    return nil
  }

  private func removingFinalSemivowels(from nuclei: [Int]) -> [Int] {
    var nuclei = nuclei
    guard !nuclei.isEmpty && !rule.finalSemivowelsSet.isEmpty else { return nuclei }

    let lastNucleusIndex = nuclei[nuclei.count - 1]
    let lastToken = tokens[lastNucleusIndex]
    let isFinal = (lastNucleusIndex + 1..<tokens.count).allSatisfy {
      tokens[$0].tokenClass == .separator || tokens[$0].tokenClass == .other
    }

    guard isFinal,
      let firstCharacter = lastToken.surface.lowercased().first,
      rule.finalSemivowelsSet.contains(firstCharacter),
      lastNucleusIndex > 0,
      tokens[lastNucleusIndex - 1].tokenClass == .consonant
    else { return nuclei }

    nuclei.removeLast()
    return nuclei
  }

  private func addingSyllabicConsonants(to nuclei: [Int]) -> [Int] {
    guard !rule.syllabicConsonantSet.isEmpty && !nuclei.isEmpty else { return nuclei }

    let syllabicNuclei = tokens.indices.filter { index in
      let token = tokens[index]
      return token.tokenClass == .consonant
        && token.surface.count == 1
        && token.surface.lowercased().first.map(rule.syllabicConsonantSet.contains) == true
        && isSurroundedByConsonants(index)
        && hasBufferToVowels(index)
    }
    return (Set(nuclei).union(syllabicNuclei)).sorted()
  }

  private func isSurroundedByConsonants(_ index: Int) -> Bool {
    let previousIsConsonant = index == 0 || tokens[index - 1].tokenClass == .consonant
    let nextIsConsonant = index == tokens.count - 1 || tokens[index + 1].tokenClass == .consonant
    return previousIsConsonant && nextIsConsonant
  }

  private func hasBufferToVowels(_ index: Int) -> Bool {
    let previousVowel = tokens[..<index].lastIndex { $0.tokenClass == .vowel }
    let nextVowel =
      tokens.index(after: index) < tokens.endIndex
      ? tokens[tokens.index(after: index)...].firstIndex { $0.tokenClass == .vowel }
      : nil
    return previousVowel.map { index - $0 > 1 } ?? true
      && nextVowel.map { $0 - index > 1 } ?? true
  }

  private func fallbackSyllabicConsonants() -> [Int] {
    tokens.indices.filter { index in
      let token = tokens[index]
      return token.tokenClass == .consonant
        && token.surface.count == 1
        && token.surface.lowercased().first.map(rule.syllabicConsonantSet.contains) == true
    }
  }
}
