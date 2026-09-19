PYTHON_DATA_DIR = ../syllabreak-python/syllabreak/data
SWIFT_RESOURCES_DIR = Sources/Syllabreak/Resources
SWIFT_TEST_RESOURCES_DIR = Tests/SyllabreakTests/Resources
COMMENTCENSOR_VERSION ?= v0.3.2
COMMENTCENSOR_ENV = .build/commentcensor
COMMENTCENSOR = $(COMMENTCENSOR_ENV)/bin/commentcensor

.DEFAULT_GOAL := build

.PHONY: install-tools build test-build test docs format comments lint lint-fix clean install sync-yaml

install-tools:
	brew install swiftlint swift-format
	python3 -m venv $(COMMENTCENSOR_ENV)
	$(COMMENTCENSOR_ENV)/bin/pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git@$(COMMENTCENSOR_VERSION)

format:
	swift-format format --in-place --recursive Sources Tests Package.swift

comments:
	$(COMMENTCENSOR) .

lint: comments
	swiftlint --strict
	swift-format lint --strict --recursive Sources Tests Package.swift

test-build:
	swift build --build-tests

test:
	swift test

docs:
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target Syllabreak --output-path .build/docc \
		--warnings-as-errors \
		--transform-for-static-hosting \
		--hosting-base-path syllabreak-swift

build: lint test-build test docs
	swift build

lint-fix:
	$(MAKE) format

clean:
	swift package clean
	rm -rf .build Package.resolved

install:
	$(MAKE) install-tools

sync-yaml:
	cp $(PYTHON_DATA_DIR)/rules.yaml $(SWIFT_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/word_split_rules.yaml $(SWIFT_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/syllabify_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/detect_language_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/word_split_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
	cp $(PYTHON_DATA_DIR)/tokenizer_tests.yaml $(SWIFT_TEST_RESOURCES_DIR)/
