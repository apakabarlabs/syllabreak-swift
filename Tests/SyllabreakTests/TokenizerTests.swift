import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

struct TokenizerTests {
  struct TestData: Codable {
    let tests: [TestCase]
  }

  struct TestCase: Codable, CustomTestStringConvertible {
    let name: String
    let rule: LanguageRule
    let text: String
    let normalization: String?
    let tokens: [ExpectedToken]

    var testDescription: String { name }
  }

  struct ExpectedToken: Codable {
    let surface: String
    let `class`: String
    let modifier: Bool?
    let start: Int
    let end: Int
  }

  static var testCases: [TestCase] {
    let data: TestData = Embedded.getYAML(Bundle.module, path: "tokenizer_tests.yaml")
    return data.tests
  }

  @Test(arguments: testCases)
  func tokenizer(testCase: TestCase) {
    let text =
      testCase.normalization == "nfd"
      ? testCase.text.decomposedStringWithCanonicalMapping : testCase.text
    let actual = Tokenizer(word: text, rule: testCase.rule).tokenize()

    #expect(actual.count == testCase.tokens.count)
    for (token, expected) in zip(actual, testCase.tokens) {
      #expect(token.surface == expected.surface)
      #expect(tokenClassName(token.tokenClass) == expected.class)
      #expect(token.isModifier == (expected.modifier ?? false))
      #expect(token.startIdx == expected.start)
      #expect(token.endIdx == expected.end)
    }
  }

  private func tokenClassName(_ tokenClass: TokenClass) -> String {
    switch tokenClass {
    case .vowel: "vowel"
    case .consonant: "consonant"
    case .separator: "separator"
    case .other: "other"
    }
  }
}
