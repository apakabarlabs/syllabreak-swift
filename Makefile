PYTHON_DATA_DIR = ../syllabreak-python/syllabreak/data
SWIFT_RESOURCES_DIR = Sources/Syllabreak/Resources
SWIFT_TEST_RESOURCES_DIR = Tests/SyllabreakTests/Resources

.PHONY: build test docs lint clean install convert-yaml

build:
	swift build

test:
	swift test

docs:
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target Syllabreak --output-path .build/docc \
		--warnings-as-errors \
		--transform-for-static-hosting \
		--hosting-base-path syllabreak-swift

lint:
	swiftlint

lint-fix:
	swiftlint --fix

clean:
	swift package clean
	rm -rf .build Package.resolved

install:
	brew install swiftlint

sync-yaml:
	cp $(PYTHON_DATA_DIR)/rules.yaml $(SWIFT_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/word_split_rules.yaml $(SWIFT_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/syllabify_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/detect_language_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/word_split_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
