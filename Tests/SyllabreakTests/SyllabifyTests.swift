import Foundation
import SwiftEmbed
import Testing

@testable import Syllabreak

struct SyllabifyTests {

  struct TestSection: Codable {
    let section: String
    let lang: String?
    let cases: [TestCase]
  }

  struct TestCase: Codable {
    let text: String
    let want: String
  }

  struct TestData: Codable {
    let tests: [TestSection]
  }

  struct LoadedTestCase: CustomTestStringConvertible {
    let section: String
    let lang: String?
    let text: String
    let want: String

    var testDescription: String {
      "[\(section)] \(text)"
    }
  }

  static var testData: TestData {
    Embedded.getYAML(Bundle.module, path: "syllabify_tests.yaml")
  }

  static var testCases: [LoadedTestCase] {
    var cases: [LoadedTestCase] = []
    for section in testData.tests {
      for testCase in section.cases {
        cases.append(
          LoadedTestCase(
            section: section.section,
            lang: section.lang,
            text: testCase.text,
            want: testCase.want
          ))
      }
    }
    return cases
  }

  @Test(arguments: testCases)
  func syllabify(testCase: LoadedTestCase) {
    let syllabifier = Syllabreak(softHyphen: "-")

    let result: String
    if let lang = testCase.lang {
      result = syllabifier.syllabify(testCase.text, lang: lang)
    } else {
      result = syllabifier.syllabify(testCase.text)
    }

    #expect(
      result == testCase.want,
      "[\(testCase.section)] Failed for '\(testCase.text)': got '\(result)', want '\(testCase.want)'"
    )
  }
}
