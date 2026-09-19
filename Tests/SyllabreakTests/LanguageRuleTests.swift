import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

private enum LanguageRuleTestDataKey: String, CodingKey {
  case tests
  case mappingTests = "mapping_tests"
}

struct LanguageRuleTests {
  struct TestData: Codable {
    let tests: [TestCase]
    let mappingTests: [MappingTestCase]

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: LanguageRuleTestDataKey.self)
      tests = try container.decode([TestCase].self, forKey: .tests)
      mappingTests = try container.decode([MappingTestCase].self, forKey: .mappingTests)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: LanguageRuleTestDataKey.self)
      try container.encode(tests, forKey: .tests)
      try container.encode(mappingTests, forKey: .mappingTests)
    }
  }

  struct MappingTestCase: Codable, CustomTestStringConvertible {
    let name: String
    let mapping: [String: String]
    let expected: [MappingEntry]

    var testDescription: String { name }
  }

  struct MappingEntry: Codable {
    let key: String
    let value: String
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

  static var mappingTestCases: [MappingTestCase] {
    let data: TestData = Embedded.getYAML(Bundle.module, path: "language_rule_tests.yaml")
    return data.mappingTests
  }

  @Test(arguments: testCases)
  func augmentStrings(testCase: TestCase) {
    #expect(LanguageRule.augmentStrings(testCase.values) == Set(testCase.expected))
  }

  @Test(arguments: mappingTestCases)
  func augmentMapping(testCase: MappingTestCase) {
    let actual = LanguageRule.augmentMapping(testCase.mapping)
    for expected in testCase.expected {
      #expect(actual[expected.key] == expected.value)
    }
  }
}
