import Foundation

extension WordSyllabifier {
  /// Render the result, collapsing geminate expansions that don't split.
  ///
  /// For each geminate span we keep the expanded surface only when a
  /// boundary actually falls between its tokens. Otherwise the span
  /// collapses back to its original compact text — the caller never sees
  /// a cosmetic expansion that wasn't earned by an actual line break.
  func renderWithGeminateSpans(boundaries: [Int]) -> String {
    let boundarySet = Set(boundaries)
    let spanRanges = spanTokenRanges()
    let spansWithInternal = spansContainingAnyBoundary(spanRanges, boundarySet: boundarySet)
    let tokenToSpan = tokenToSpanIndex(spanRanges)

    var output = ""
    var i = 0
    while i < tokens.count {
      if let sIdx = tokenToSpan[i], !spansWithInternal.contains(sIdx) {
        let range = spanRanges[sIdx]
        if i == range.first && boundarySet.contains(i) {
          output += softHyphen
        }
        output += range.compact
        i = range.last + 1
      } else {
        if boundarySet.contains(i) {
          output += softHyphen
        }
        output += tokens[i].surface
        i += 1
      }
    }
    return output
  }

  struct TokenSpanRange {
    let first: Int
    let last: Int
    let compact: String
  }

  func spanTokenRanges() -> [TokenSpanRange] {
    var ranges: [TokenSpanRange] = []
    for span in geminateSpans {
      let end = span.start + span.length
      var first: Int?
      var last: Int?
      for (i, token) in tokens.enumerated()
      where token.startIdx >= span.start && token.endIdx <= end {
        if first == nil { first = i }
        last = i
      }
      if let first, let last {
        ranges.append(TokenSpanRange(first: first, last: last, compact: span.compactOriginal))
      }
    }
    return ranges
  }

  func spansContainingAnyBoundary(_ ranges: [TokenSpanRange], boundarySet: Set<Int>) -> Set<Int> {
    var result: Set<Int> = []
    for (sIdx, range) in ranges.enumerated() {
      for b in boundarySet where b > range.first && b <= range.last {
        result.insert(sIdx)
        break
      }
    }
    return result
  }

  func tokenToSpanIndex(_ ranges: [TokenSpanRange]) -> [Int: Int] {
    var mapping: [Int: Int] = [:]
    for (sIdx, range) in ranges.enumerated() {
      for t in range.first...range.last {
        mapping[t] = sIdx
      }
    }
    return mapping
  }

  /// Render an exception's hyphen-marked lowercase split using the original case.
  func applyException(_ splitLower: String) -> String {
    var result = ""
    let wordChars = Array(originalWord)
    var srcIdx = 0
    for ch in splitLower {
      if ch == "-" {
        result += softHyphen
      } else {
        result.append(wordChars[srcIdx])
        srcIdx += 1
      }
    }
    return result
  }
}
