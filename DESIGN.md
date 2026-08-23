# Cairn Design Guidelines

This file summarizes the principles behind Cairn's UI design and serves as the entry point to the detailed docs. Before adding or changing any UI, read the relevant `docs/design/*.md` file linked below first. When this file conflicts with CLAUDE.md or docs/progress.md, the priority order is CLAUDE.md > docs/progress.md (phase definitions) > this file (visual/interaction conventions).

## Reference mockup

The full-screen UI mockup for Phase5 and beyond (Discovery / Install / Settings / Library / AppDetail / error states, including the sidebar pin/unpin interaction) is published as a Claude Design canvas:

**https://claude.ai/code/artifact/7e00278f-4145-4e9e-82fe-7fb6495a994f**

This mockup, built as web HTML (`.dc.html`), is the primary visual-design reference and the source of truth for the SwiftUI implementation. If the visuals drift from this mockup as implementation progresses, update whichever side is stale as soon as you notice — don't let them diverge silently.

## Apps we're taking cues from

- **App Store (Mac)**: the base structure — `NavigationSplitView` + category sidebar + card grid
- **Cork / Latest-style Homebrew GUIs**: function-first, low-chrome information density
- **System Settings**: grouped list presentation (Settings screen)
- **Xcode**: the sidebar's "unpin → reveal on hover" interaction

Custom brand color is kept to a minimum. Faithful native macOS presentation is the top priority throughout.

## Principles (see each doc for detail)

1. **[Liquid Glass is for the control layer only](docs/design/colors-and-materials.md)** — limited to the sidebar, title bar, and transient overlays. Applying it to content-layer surfaces (grids, README, etc.) or the whole window is prohibited (per Apple's own guidance).
2. **[Colors and materials must support both light and dark](docs/design/colors-and-materials.md)** — whether CSS variables or SwiftUI Color assets, always define both the light and dark values.
3. **[Typography and spacing follow system defaults](docs/design/typography-and-spacing.md)** — the `-apple-system`/San Francisco-equivalent font stack, and macOS-standard control heights and spacing scale.
4. **[Icons are SF Symbols only — no vibe-coded glyphs](docs/design/iconography.md)** — the implementation must always reference a real SF Symbol name via `Image(systemName:)`. Icons in the mockup are visual approximations of the SF Symbols style; the mapping table is the source of truth.
5. **[Motion is feedback-only, and Reduce Motion is always honored](docs/design/motion.md)** — avoid "motion for motion's sake."
6. **[The sidebar has two states: pinned and unpinned](docs/design/sidebar-interaction.md)** — when unpinned, hovering the left edge reveals it as a temporary overlay (same model as Xcode's navigator).
7. **[Errors are never swallowed](docs/design/error-handling-ui.md)** — search failures, rate limiting, network loss, and install failures must always surface via an inline banner, an empty state, or a modal alert.
8. **[README/description text auto-translates to Japanese when the system language is Japanese, with a toggle back to the original](docs/design/localization.md)** — on-device translation via Apple's Translation framework. GitHub user IDs, app names, and code are never translated.

## Detailed docs

| Doc | Contents |
|---|---|
| [docs/design/colors-and-materials.md](docs/design/colors-and-materials.md) | Light/dark color tokens, Liquid Glass applicability table |
| [docs/design/typography-and-spacing.md](docs/design/typography-and-spacing.md) | Font stack, type scale, spacing/control-height scale |
| [docs/design/iconography.md](docs/design/iconography.md) | SF-Symbols-only policy, licensing constraints, icon mapping table |
| [docs/design/motion.md](docs/design/motion.md) | Animation principles, recommended spring values, Reduce Motion implementation pattern |
| [docs/design/sidebar-interaction.md](docs/design/sidebar-interaction.md) | Exact spec for the sidebar's pin/unpin and hover-overlay behavior |
| [docs/design/error-handling-ui.md](docs/design/error-handling-ui.md) | The three never-swallow-errors UI patterns and how they map to existing error types |
| [docs/design/localization.md](docs/design/localization.md) | README/description auto-translation policy (Apple Translation framework, translation boundaries, Markdown translation caveats) |

## Status of this document

These conventions were settled during the August 2026 UI visual brainstorming session (before Phase5 implementation began). When implementing Phase6–11 (AppDetail/Install/Uninstall/Sparkle/Onboarding/Settings), any deviation from the principles here must be explained in the commit message or PR description.
