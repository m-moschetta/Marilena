# Repository Guidelines

## Project Structure & Module Organization
- iOS app: `Marilena/` (SwiftUI views, services, Core Data `Marilena.xcdatamodeld`).
- macOS app: `Marilena-Mac/` (`Marilena_MacApp.swift`, `Marilena_Mac.xcdatamodeld`).
- Tests: `MarilenaTests/` (unit, Swift Testing), `MarilenaUITests/` (XCTest UI), `Marilena-MacTests/`.
- Support: `docs/`, `Marilena/Assets.xcassets`, `Marilena-Mac/Assets.xcassets`, `scripts/`.
- Notable modules: `AIProviderManager.swift`, `OpenAIService.swift`, `AnthropicService.swift`, `PerplexityService.swift`, `GroqService.swift`, `SpeechTranscriptionService.swift`, `Core/` utilities.

## Build, Test, and Development Commands
- Open in Xcode:
  ```bash
  open Marilena.xcodeproj
  ```
- iOS build + tests:
  ```bash
  xcodebuild -scheme Marilena \
    -destination 'platform=iOS Simulator,name=iPhone 15' build test
  ```
- macOS build + tests:
  ```bash
  xcodebuild -scheme Marilena-Mac -destination 'platform=macOS' build test
  ```
- OAuth helper (see docs):
  ```bash
  bash Marilena/scripts/setup_oauth.sh
  ```

## Coding Style & Naming Conventions
- Swift, 2‑space indentation; follow Swift API Design Guidelines.
- Types `UpperCamelCase`; methods/properties `lowerCamelCase`.
- Views end with `View` (e.g., `EmailListView`); services end with `Service`.
- Prefer `struct`, Swift Concurrency (`async/await`); mark `final` where appropriate.
- Keep files focused (one type per file); co‑locate tests in the matching `*Tests` folder.

## Testing Guidelines
- Frameworks: Swift Testing for unit (`import Testing`), XCTest for UI.
- Naming: `FeatureNameTests.swift`; one behavior per `@Test`.
- Run via Xcode or with the `xcodebuild ... test` commands above for iOS/macOS.
- Aim for meaningful coverage on AI services, speech, and persistence.

## Commit & Pull Request Guidelines
- Commits: small, imperative mood; optional emoji + tag consistent with history (e.g., `🔧 Phase: short change`).
- Branches: `feature/<slug>`, `fix/<slug>`, `chore/<slug>`.
- PRs: clear description, linked issues, screenshots/GIFs for UI, validation steps, and notes on migrations or `Info.plist` changes.

## Security & Configuration Tips
- Never hard‑code API keys; store in Keychain via `KeychainManager.swift` and in‑app settings.
- Do not commit personal credentials. Review `Info.plist` updates for both iOS and macOS targets.
