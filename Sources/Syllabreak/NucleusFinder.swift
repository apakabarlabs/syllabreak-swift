struct NucleusFinder {
  let tokens: [Token]
  let rule: LanguageRule

  func find() -> [Int] {
    var nuclei = vowelNuclei()
    nuclei = removingFinalSemivowels(from: nuclei)
    nuclei = addingSyllabicConsonants(to: nuclei)
    return nuclei.isEmpty ? fallbackSyllabicConsonants() : nuclei
  }

  private func vowelNuclei() -> [Int] {
    tokens.indices.filter { tokens[$0].tokenClass == .vowel }
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
