# Changelog

## 0.19.1

### Changed

- Internal refactor and stricter automated checks; drop-in update with no API or behavior changes.

## 0.19.0

### Fixed — syllable-division correctness
- **`й` no longer counted as a syllable nucleus** (rus/kaz/kir). It decomposes
  under NFD to `и` + combining breve; the engine now recomposes it back to the
  consonant before tokenisation, so `мой` → `мой`, `война` → `вой-на`.
- **Russian vowel hiatus splits**: `по-э-зи-я`, `на-у-ка`, `со-юз`.
- **Hard sign `ъ` holds the syllable boundary**: `об-ъект`, `под-ъезд`, `из-ъян`.
- **Kazakh/Kyrgyz `у`/`и`**: Kazakh models them as context-dependent glides
  (`да-уа`, not `да-у-а`; `ди-а-лог`); Kyrgyz splits hiatus (`а-ян`, `кы-ял`).

### Changed — internal, behaviour-preserving
- Removed dead rule fields `modifiers_attach_right`, `sonorants`, `glides`
  (and the `isGlide` token flag), and the redundant empty-default lines in
  `rules.yaml`.
- Deduplicated the BCMS-Latin and Serbian/Montenegrin Cyrillic rule families
  with YAML anchors.
- Bumped GitHub Actions to the Node 24 major (`checkout@v6`).
