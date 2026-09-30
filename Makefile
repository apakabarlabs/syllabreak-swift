.DEFAULT_GOAL := build

.PHONY: install-tools build test-build test docs format comments lint lint-fix clean install

install-tools:
	brew install swiftlint swift-format
	python3 -m pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git

format:
	swift-format format --in-place --recursive Sources Tests Package.swift

comments:
	commentcensor .

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
