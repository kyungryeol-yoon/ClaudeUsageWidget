# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a pure Xcode project — open `ClaudeUsageWidget.xcodeproj` and run from there. There is no Swift Package Manager manifest or CLI build script.

```bash
# Build from CLI (substitute your scheme/destination as needed)
xcodebuild -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -configuration Debug build

# Run tests (no test target exists yet)
xcodebuild test -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget
```

The app requires macOS 13+ (`MenuBarExtra` API).

## Prerequisites

The app reads OAuth credentials written by the Claude Code CLI. Before running, the user must have executed `claude login` in a terminal, which stores a JSON payload under the keychain service **`Claude Code-credentials`**.

## Architecture

The app is a menubar-only app (`LSUIElement = true`, no Dock icon) built entirely with SwiftUI and `MenuBarExtra`.

**Data flow:**

```
CredentialsLoader (Keychain) → UsageFetcher (Anthropic API) → UsageViewModel → UI
```

- **`CredentialsLoader`** — Reads the keychain item for service `"Claude Code-credentials"` and decodes the `claudeAiOauth` field into `ClaudeCredentials` (access token, refresh token, expiry, subscription type).
- **`UsageFetcher`** — Stateless enum that POSTs to `https://api.anthropic.com/api/oauth/usage` with `anthropic-beta: oauth-2025-04-20`. Returns `UsageResponse` with `fiveHour` and `sevenDay` `UsageBucket`s (each has `utilization` 0–100 and `resetsAt` ISO-8601 string).
- **`UsageViewModel`** — `@MainActor ObservableObject`. Owns the repeating `Timer` (driven by `AppSettings.refreshInterval`). On each tick it calls `CredentialsLoader → UsageFetcher`, normalises utilization to 0–1, and writes to `UserDefaults` as a cache. On failure it marks `isStale = true` and keeps the last cached values visible.
- **`AppSettings`** — Singleton `ObservableObject` (`AppSettings.shared`). Persists `displayStyle`, `refreshInterval`, and `menuBarIcon` to `UserDefaults`. Changing `refreshInterval` triggers `UsageViewModel` to restart its timer via a Combine sink.

**UI layer:**

- **`ClaudeUsageWidgetApp`** — `@main`. Passes `viewModel.usage`, `settings.displayStyle`, and `settings.menuBarIcon` explicitly to `MenuBarLabel` so SwiftUI can diff and re-render the label when any value changes.
- **`MenuBarLabel`** — Renders the compact indicator in the system menu bar. Supports four `DisplayStyle` variants: `ring`, `dual`, `bar`, `dot`. Color thresholds: green < 60 %, orange < 85 %, red ≥ 85 %.
- **`PopoverView`** — The `.window`-style popover. Shows two `RingWithReset` circles (5-hour and weekly), a stale/cached badge, inline settings via `SettingsPanel`, and Refresh / Quit buttons.
- **`DateUtils`** (`ResetTimeFormatter`) — Formats a future `Date` into a Korean countdown string (e.g. "2시간 34분 후").

## Key design notes

- `ContentView.swift` is the Xcode-generated stub and is not used by the app.
- Logo assets (`ClaudeLogo.imageset/`, `AppIcon.appiconset/`) are git-ignored to avoid trademark issues — you must supply your own images locally.
- The app has no entitlements; keychain access works because the item was created by another process under the same user.
