import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

struct LanguageRuleTests {
  struct TestData: Codable {
    let tests: [TestCase]
  }

  struct TestCase: Codable, CustomTestStringConvertible {
    let name: String
    let values: [String]
    let expected: [String]

    var testDescription: String { name }
  }

  static var testCases: [TestCase] {
    let data: TestData = Embedded.getYAML(Bundle.module, path: "language_rule_tests.yaml")
    return data.tests
  }

  @Test(arguments: testCases)
  func augmentStrings(testCase: TestCase) {
    #expect(LanguageRule.augmentStrings(testCase.values) == Set(testCase.expected))
  }
}
