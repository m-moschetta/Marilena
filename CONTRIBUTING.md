# Contributing Guide

Thank you for contributing to Marilena! Before starting, read the Repository Guidelines in `AGENTS.md` for structure, style, and workflows.

## Getting Started
- Clone and create a feature branch:
  ```bash
  git clone <repo-url>
  cd Marilena
  git checkout -b feature/<slug>
  open Marilena.xcodeproj
  ```
- Configure API keys in-app (stored via Keychain). Do not commit secrets.

## Commit Messages
- Imperative mood, small scope; reference issues when relevant.
- Emoji prefixes are optional; follow existing history (e.g., `🔧`, `🏗️`, `🎨`).

## Pull Request Checklist
- Branch name follows `feature/<slug>` or `fix/<slug>`.
- Rebase/sync with `main`; resolve conflicts locally.
- Builds pass for both targets:
  ```bash
  xcodebuild -scheme Marilena -destination 'platform=iOS Simulator,name=iPhone 15' build test
  xcodebuild -scheme Marilena-Mac -destination 'platform=macOS' build test
  ```
- Tests added/updated for services and critical views.
- UI change? Include screenshots/GIFs and short UX notes.
- Docs updated if behavior, settings, or plist changed (`README.md`, `AGENTS.md`).
- No secrets or personal data in diffs; review `Info.plist` changes.
- Link related issues and add migration notes if needed.

## Code Style & Tests
- Swift 2-space indentation; follow Swift API Design Guidelines.
- Naming: `TypeName`, `propertyName`; suffix `View`/`Service` consistently.
- Prefer `async/await`, `struct`, and small, focused files.
- Place tests in the matching `*Tests` target; name `FeatureNameTests.swift`.

## Reporting Issues
- Provide steps to reproduce, logs/crash info, iOS/macOS versions, and screenshots when applicable.
