import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

struct DetectLanguageTests {

  struct TestGroup: Codable {
    let lang: String?
    let cases: [String]
  }

  struct TestData: Codable {
    let tests: [TestGroup]
  }

  struct LanguageTestCase: CustomTestStringConvertible {
    let text: String
    let expected: [String]

    var testDescription: String {
      text
    }
  }

  static var testData: TestData {
    Embedded.getYAML(Bundle.module, path: "detect_language_tests.yaml")
  }

  static var testCases: [LanguageTestCase] {
    var cases: [LanguageTestCase] = []
    for group in testData.tests {
      let expected = group.lang.map { [$0] } ?? []
      for text in group.cases {
        cases.append(LanguageTestCase(text: text, expected: expected))
      }
    }
    return cases
  }

  @Test(arguments: testCases)
  func detectLanguage(testCase: LanguageTestCase) {
    let s = Syllabreak()
    let result = s.detectLanguage(testCase.text)

    if !testCase.expected.isEmpty {
      #expect(
        !result.isEmpty,
        "Failed for '\(testCase.text)': got empty result, expected \(testCase.expected)")
      if !result.isEmpty {
        let first = result[0]
        let expected = testCase.expected[0]
        #expect(
          first == expected,
          "Failed for '\(testCase.text)': got \(first) as first (from \(result)), expected \(expected)"
        )
      }
    } else {
      #expect(
        result == [],
        "Failed for '\(testCase.text)': got \(result), expected empty list")
    }
  }
}
