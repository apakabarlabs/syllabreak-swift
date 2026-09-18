PYTHON_DATA_DIR = ../syllabreak-python/syllabreak/data
SWIFT_RESOURCES_DIR = Sources/Syllabreak/Resources
SWIFT_TEST_RESOURCES_DIR = Tests/SyllabreakTests/Resources
.PHONY: build test docs format lint lint-fix clean install sync-yaml

format:
	swift-format format --in-place --recursive Sources Tests Package.swift

lint:
	swiftlint
	swift-format lint --strict --recursive Sources Tests Package.swift

test:
	swift test

docs:
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target Syllabreak --output-path .build/docc \
		--warnings-as-errors \
		--transform-for-static-hosting \
		--hosting-base-path syllabreak-swift

build:
	swift build

lint-fix:
	$(MAKE) format

clean:
	swift package clean
	rm -rf .build Package.resolved

install:
	brew install swiftlint swift-format

sync-yaml:
	cp $(PYTHON_DATA_DIR)/rules.yaml $(SWIFT_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/word_split_rules.yaml $(SWIFT_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/syllabify_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/detect_language_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/word_split_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
