import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

struct WordSplitTests {
  struct TestCase: Codable {
    let lang: String
    let text: String
    let expected: [String]
  }

  struct TestData: Codable {
    let tests: [TestCase]
  }

  struct LoadedCase: CustomTestStringConvertible {
    let lang: String
    let text: String
    let expected: [String]

    var testDescription: String {
      "[\(lang)] \(text)"
    }
  }

  static var testCases: [LoadedCase] {
    let data: TestData = Embedded.getYAML(Bundle.module, path: "word_split_tests.yaml")
    return data.tests.map {
      LoadedCase(lang: $0.lang, text: $0.text, expected: $0.expected)
    }
  }

  @Test(arguments: testCases)
  func split(testCase: LoadedCase) {
    let splitter = WordSplitter()
    let result = splitter.split(testCase.text, lang: testCase.lang)
    #expect(
      result == testCase.expected,
      "[\(testCase.lang)] '\(testCase.text)': got \(result), want \(testCase.expected)")
  }
}
