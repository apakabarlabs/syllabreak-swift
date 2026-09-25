# ``Syllabreak``

Detect languages, split text into words, and insert configurable markers at
orthographic syllable boundaries.

## Syllabify text

Create ``Syllabreak`` with a visible separator for display, or use its default U+00AD
soft hyphen for layout engines.

```swift
import Syllabreak

let syllabifier = Syllabreak(softHyphen: "-")
let english = syllabifier.syllabify("problem", lang: "eng")
let russian = syllabifier.syllabify("привет", lang: "rus")
```

Omit `lang` to use the first result from ``Syllabreak/detectLanguage(_:)``. Explicit
language selection is preferable for languages that share an alphabet, such as English,
German, Dutch, Finnish, and several Latin-script BCMS languages. Unsupported explicit
codes and text for which no rule matches are returned unchanged.

The engine uses bundled orthographic rules with bounded lexical exceptions rather than a
general pronunciation dictionary. It preserves punctuation and spacing. Results produced
by a language rule are normalized to NFC; unsupported-language and no-match fallbacks are
returned unchanged, including their original normalization.

## Split text into words

``WordSplitter`` returns either word surfaces or their exact source ranges. Most language
codes use a Unicode-aware default mode. Chinese, Japanese, and Korean codes use a CJK mode
covering the bundled BMP Han Unified, Extension A, Compatibility, Hiragana, Katakana, and
precomposed Hangul-syllable ranges while preserving ASCII letter and digit runs.

```swift
let splitter = WordSplitter()
let words = splitter.split("Don't stop.", lang: "eng")
let ranges = splitter.findRanges("the cat and the cat", lang: "eng")
```

## Topics

### Syllabification

- ``Syllabreak``
- ``Syllabreak/init(softHyphen:)``
- ``Syllabreak/defaultSoftHyphen``
- ``Syllabreak/syllabify(_:lang:)``
- ``Syllabreak/detectLanguage(_:)``
- ``Syllabreak/supportedLanguages()``

### Word splitting

- ``WordSplitter``
- ``WordSplitter/split(_:lang:)``
- ``WordSplitter/findRanges(_:lang:)``
