# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Cairn is a native macOS app (SwiftUI, `.macOS(.v26)` minimum) for discovering, installing, and uninstalling apps distributed via GitHub Releases. It is distributed **unsigned** (no Developer ID certificate) and updates itself via Sparkle using EdDSA-signed appcasts instead of OS code-signing verification.

Currently at Phase 0.5 (toolchain setup) — see `docs/progress.md` for phase-by-phase status. The full implementation plan lives outside `docs/` in a Claude Code plan file; `docs/progress.md` is the authoritative day-to-day checklist.

## Commands

All commands run through `just` (see `justfile`). Requires `brew install swiftlint swift-format lefthook xcbeautify`.

```bash
just setup        # verify toolchain + install git hooks (lefthook)
just build         # debug build via scripts/build.sh (xcbeautify-formatted)
just release        # release build, plain `swift build -c release` (no xcbeautify)
just test          # run tests via scripts/test.sh (xcbeautify-formatted)
just format        # swift-format --in-place over Sources/ and Tests/
just lint          # swift-format lint (check-only) + swiftlint
just run           # debug build + launch, via scripts/run.sh
just run-release   # release build + launch (`swift run -c release Cairn`)
just clean         # rm -rf .build
```

To run a single test, bypass the justfile/xcbeautify wrapper and use `swift test` directly with a filter, e.g. `swift test --filter CairnAppTests`.

**xcbeautify gotcha**: `scripts/build.sh` / `scripts/test.sh` always pass `--preserve-unbeautified` — without it, xcbeautify doesn't recognize plain `swift build`/`swift test` output and silently discards it. In CI (`CI=true`), the scripts additionally pass `--is-ci --renderer github-actions`.

Pre-commit (via lefthook) runs `swift-format --in-place` (re-staging changed files) then `swiftlint lint` on staged `*.swift` files.

## CI

- `ci.yml` / `test.yml` trigger only on push/PR touching `**/*.swift`, run on `macos-26`.
- `release.yml` is `workflow_dispatch`-only (never automatic), builds `-c release` without xcbeautify, and packages a `.dmg` via `create-dmg` (prerelease GitHub Release, EdDSA-signed appcast update is a separate Sparkle step). `scripts/build-dmg.sh` does not exist yet — that release job step is a placeholder until packaging is implemented in a later phase.

## Architecture

Single-target SwiftPM project — **no `.xcodeproj`**; `Package.swift` is the sole source of truth for dependencies and targets (chosen for lower Git-conflict surface and simpler CLI builds; see `docs/dependencies.md` for the full rationale).

`Sources/Cairn/` layout:
- `App/` — `CairnApp.swift` entry point
- `GitHubClient/` — GitHub API access; `Auth/` (Device Flow OAuth) and `Models/` (Codable API response types) subfolders
- `Cache/` — local persistence/caching layer
- `Classification/` — noise-filtering/classification logic for distinguishing real apps from other GitHub repos
- `Installation/` / `Uninstallation/` — app install (`.dmg`/`.zip` handling, copy to `/Applications`) and uninstall (remove app + related files) logic
- `Features/` — SwiftUI feature modules: `AppDetail`, `Discovery`, `Install`, `Library`, `Onboarding`, `Settings`
- `Resources/` — `Info.plist` and `Cairn.entitlements`. Both are **excluded** from SwiftPM's `resources:` processing in `Package.swift` (SwiftPM forbids `Info.plist` at a resource bundle's top level); a release build script copies them into the `.app` bundle manually.

Key architectural patterns in use (see `docs/dependencies.md` for the full pattern-to-file mapping):
- `GitHubClientProtocol` — protocol abstraction over the GitHub client for test mocking
- `Observation` framework for observer-pattern state (no Combine)
- Factory-style dispatch in `InstallService` based on asset type (`.dmg` vs `.zip`)

### Dependencies (`Package.swift`)

| Package | Purpose |
|---|---|
| Sparkle | Self-update via EdDSA-signed appcasts (required because the app is unsigned) |
| ZIPFoundation | `.zip` release asset extraction (`.dmg` uses `hdiutil` directly, no dependency needed) |
| Defaults | Type-safe `UserDefaults` wrapper for settings |
| Permiso (`zats/permiso`) | Deep-links to the System Settings "App Management" privacy panel, needed because installing/uninstalling other apps requires this permission |

Notes when touching dependencies:
- `permiso` is pinned to a specific commit `revision:` (not a tag, not `branch: "main"`) — it has no tagged releases and no confirmed LICENSE file. Do not switch it to `branch:` tracking (supply-chain risk) or bump it without re-checking the license question in `docs/dependencies.md`.
- New third-party dependencies should be weighed against the project's minimal-dependency, Apple-API-first bias (see the "unadopted" table in `docs/dependencies.md` for prior rejections and why).

### Versioning

`version.env` holds `MARKETING_VERSION` / `BUILD_NUMBER` as the single source of truth (single-channel only — no Beta channel yet). `release.yml` reads from it unless a version is supplied via `workflow_dispatch` input.

## Development practices

- **Phased execution**: implement one phase at a time (per `docs/progress.md`); don't jump ahead to a later phase's work in the same pass unless it's tightly coupled to the phase in progress.
- **One commit per task**: when a phase breaks down into multiple tasks (or multiple bugs get fixed), commit each one separately rather than bundling them.
- **Tests**: add or update tests alongside the corresponding implementation task, not as an afterthought — every task/bugfix gets test coverage in the same commit.
- **Commit message format**: English prefixes — `feat:`, `fix:`, `ref:`, `docs:`, `chore:` — as the summary line, with `-m` flags for a brief summary, a detailed description, and technical notes as separate paragraphs.
- **Branching/PRs**: multi-phase or refactor work gets its own branch and PR, scoped per phase or per feature. Avoid squash-merging — it collapses per-task commit history, which makes it hard to reproduce pre-merge state if a later regression needs bisecting.

## Docs

- `docs/dependencies.md` — dependency adoption/rejection rationale, architectural pattern mapping, and reference-project learnings (anonymized). Read before adding/changing dependencies.
- `docs/progress.md` — phase completion checklist and known open issues (currently: Permiso license unconfirmed; `Package.swift`-only Xcode workflow not yet field-verified).
