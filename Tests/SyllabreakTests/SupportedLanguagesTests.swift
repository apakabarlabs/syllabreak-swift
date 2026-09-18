import Testing

@testable import Syllabreak

struct SupportedLanguagesTests {
  @Test
  func returnsKnownLanguageCodes() {
    let langs = Syllabreak().supportedLanguages()
    for code in ["eng", "rus", "srp-cyrl", "srp-latn", "bos", "hrv", "cnr-latn", "cnr-cyrl"] {
      #expect(langs.contains(code), "expected \(code) in supportedLanguages()")
    }
  }

  @Test
  func returnsStableNonEmptyList() {
    let s = Syllabreak()
    let first = s.supportedLanguages()
    #expect(!first.isEmpty)
    #expect(first == s.supportedLanguages())
  }
}
