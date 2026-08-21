# justfile — Cairn command runner
# Requires Homebrew tools: brew install swiftlint swift-format lefthook xcbeautify

# Default: list available commands
default:
    @just --list

# Verify dev tools are available and install git hooks
setup:
    @command -v swiftlint >/dev/null 2>&1 || (echo "Error: swiftlint not found. Run 'brew install swiftlint'." && exit 1)
    @command -v swift-format >/dev/null 2>&1 || (echo "Error: swift-format not found. Run 'brew install swift-format'." && exit 1)
    @command -v lefthook >/dev/null 2>&1 || (echo "Error: lefthook not found. Run 'brew install lefthook'." && exit 1)
    @command -v xcbeautify >/dev/null 2>&1 || (echo "Error: xcbeautify not found. Run 'brew install xcbeautify'." && exit 1)
    lefthook install
    @echo "Dev environment ready. Git hooks installed."

# Build the app (Debug), formatted with xcbeautify
build:
    bash scripts/build.sh

# Build for Release (no xcbeautify — plain swift build output)
release:
    swift build -c release

# Run all unit tests, formatted with xcbeautify
test:
    bash scripts/test.sh

# Format Swift files in-place
format:
    swift-format format --recursive --in-place Sources/ Tests/

# Lint Swift files (check only, no modification)
lint:
    swift-format lint --recursive Sources/ Tests/
    swiftlint lint

# Build (Debug) and run Cairn, formatted with xcbeautify
run:
    bash scripts/run.sh

# Same as `run` but Release configuration (no xcbeautify)
run-release:
    swift run -c release Cairn

# Remove build artifacts
clean:
    rm -rf .build
