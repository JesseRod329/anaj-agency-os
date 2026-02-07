# Contributing to ANAJ Agency OS

Thanks for contributing.

## Ground Rules

- Be respectful and constructive.
- Keep pull requests focused and reviewable.
- Prefer small, atomic commits with clear intent.
- Include validation steps for every change.

## Development Setup

```bash
open /Users/jesse/anaj1/anaj/anaj.xcodeproj
```

## Build and Test

```bash
xcodebuild -project /Users/jesse/anaj1/anaj/anaj.xcodeproj -scheme anaj -destination "platform=macOS" build
xcodebuild test -project /Users/jesse/anaj1/anaj/anaj.xcodeproj -scheme anaj -destination "platform=macOS"
```

## Coding Standards

- Swift style:
  - 4-space indentation
  - `UpperCamelCase` for types
  - `lowerCamelCase` for variables/functions
  - Use `// MARK:` for major sections
- Keep logic cohesive and name things semantically.
- Avoid broad refactors mixed with feature changes.

## Pull Request Checklist

- [ ] Scope is clear in PR title and description
- [ ] Relevant tests pass locally
- [ ] Manual QA notes are included for UI behavior
- [ ] Screenshots or recordings attached for visual changes
- [ ] New config, env vars, or behavior changes are documented

## Issue Reporting

When filing issues, include:

- Expected behavior
- Actual behavior
- Repro steps
- Environment (`macOS`, Xcode version, simulator/device)
- Logs/screenshots when relevant

