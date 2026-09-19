import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

private enum LanguageRuleTestDataKey: String, CodingKey {
  case tests
  case mappingTests = "mapping_tests"
  case geminateTests = "geminate_tests"
  case vowelNucleusRuleTests = "vowel_nucleus_rule_tests"
}

struct LanguageRuleTests {
  struct TestData: Codable {
    let tests: [TestCase]
    let mappingTests: [MappingTestCase]
    let geminateTests: [GeminateTestCase]
    let vowelNucleusRuleTests: [VowelNucleusRuleTestCase]

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: LanguageRuleTestDataKey.self)
      tests = try container.decode([TestCase].self, forKey: .tests)
      mappingTests = try container.decode([MappingTestCase].self, forKey: .mappingTests)
      geminateTests = try container.decode([GeminateTestCase].self, forKey: .geminateTests)
      vowelNucleusRuleTests = try container.decode(
        [VowelNucleusRuleTestCase].self, forKey: .vowelNucleusRuleTests)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: LanguageRuleTestDataKey.self)
      try container.encode(tests, forKey: .tests)
      try container.encode(mappingTests, forKey: .mappingTests)
      try container.encode(geminateTests, forKey: .geminateTests)
      try container.encode(vowelNucleusRuleTests, forKey: .vowelNucleusRuleTests)
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

  struct GeminateTestCase: Codable, CustomTestStringConvertible {
    let name: String
    let rule: LanguageRule
    let word: String
    let expanded: String
    let spans: [ExpectedSpan]

    var testDescription: String { name }
  }

  struct ExpectedSpan: Codable {
    let start: Int
    let length: Int
    let compact: String
  }

  struct VowelNucleusRuleTestCase: Codable, CustomTestStringConvertible {
    let name: String
    let entries: [VowelNucleusRule]
    let expected: [String]?
    let error: String?

    var testDescription: String { name }
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

  static var geminateTestCases: [GeminateTestCase] {
    let data: TestData = Embedded.getYAML(Bundle.module, path: "language_rule_tests.yaml")
    return data.geminateTests
  }

  static var vowelNucleusRuleTestCases: [VowelNucleusRuleTestCase] {
    let data: TestData = Embedded.getYAML(Bundle.module, path: "language_rule_tests.yaml")
    return data.vowelNucleusRuleTests
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

  @Test(arguments: geminateTestCases)
  func expandGeminateDigraphs(testCase: GeminateTestCase) {
    let (expanded, spans) = testCase.rule.expandGeminateDigraphs(testCase.word)
    #expect(expanded == testCase.expanded)
    #expect(spans.count == testCase.spans.count)
    for (span, expected) in zip(spans, testCase.spans) {
      #expect(span.start == expected.start)
      #expect(span.length == expected.length)
      #expect(span.compactOriginal == expected.compact)
    }
  }

  @Test(arguments: vowelNucleusRuleTestCases)
  func validateVowelNucleusRules(testCase: VowelNucleusRuleTestCase) {
    do {
      let actual = try LanguageRule.validateVowelNucleusRules(testCase.entries, vowels: "aeiou")
      #expect(testCase.error == nil)
      #expect(actual.map(\.suffix) == testCase.expected)
    } catch {
      #expect(testCase.error != nil)
      #expect(String(describing: error).contains(testCase.error ?? ""))
    }
  }
}
