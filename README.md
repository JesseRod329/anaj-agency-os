# ANAJ Agency OS

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-0A84FF)](#)
[![Swift](https://img.shields.io/badge/swift-5.0%2B-F05138)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/JesseRod329/anaj-agency-os/ci.yml?label=CI)](https://github.com/JesseRod329/anaj-agency-os/actions)
[![Issues](https://img.shields.io/github/issues/JesseRod329/anaj-agency-os)](https://github.com/JesseRod329/anaj-agency-os/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)

ANAJ Agency OS is a SwiftUI + SwiftData workspace for agency operations: clients, projects, tasks, notes, prompt workflows, insights, invoicing, and ledger reporting.

## Why ANAJ

- Agency-first data model (clients, projects, tasks, invoices, notes)
- Unified command center UX across macOS and iOS
- Built-in Prompt Studio for AI-assisted planning and insight capture
- Local API bridge for external tools and automations (`/api/*`)
- Cloud-ready structure with CloudKit support

## Core Features

- **Operations:** clients, projects, tasks, deadlines, team assignment
- **Knowledge:** notes, extraction, tagging, decisions, chat insights
- **Finance:** project financials, invoices, profitability ledger
- **AI Workflow:** Prompt Studio with provider selection and context injection
- **Automation Surface:** localhost API for OpenClaw and external tooling

## Tech Stack

- SwiftUI
- SwiftData
- CloudKit (optional)
- XCTest / XCUITest

## Project Structure

```text
anaj/
├── anaj/                  # App source (SwiftUI views, models, services)
├── anaj.xcodeproj/        # Xcode project
├── anajTests/             # Unit tests
├── anajUITests/           # UI tests
└── CLOUD_INSTRUCTIONS.md  # CloudKit setup notes
```

## Local Development

### Requirements

- macOS with Xcode 16+
- Apple toolchain for SwiftUI + SwiftData

### Run

```bash
open anaj.xcodeproj
```

### Build

```bash
xcodebuild -project anaj.xcodeproj -scheme anaj -destination "platform=macOS" build
```

### Test

```bash
xcodebuild test -project anaj.xcodeproj -scheme anaj -destination "platform=macOS"
```

## Local API (Phase 1)

The app starts a local API server when ANAJ launches:

- Base URL: `http://127.0.0.1:18790`
- Health: `GET /api/health`
- Tasks:
  - `GET /api/tasks`
  - `POST /api/tasks`
  - `PATCH /api/tasks/:id`

The API contract is evolving with the OpenClaw integration roadmap in this repository.

## Open Source

- [Contributing Guide](./CONTRIBUTING.md)
- [Code of Conduct](./CODE_OF_CONDUCT.md)
- [Security Policy](./SECURITY.md)
- [Support](./SUPPORT.md)
- [License](./LICENSE)

## Roadmap (High Level)

- Prompt Studio provider expansion (OpenClaw provider)
- Notification bridge for external channels
- Memory sync across AI + notes context
- Agent-driven workflows for specialized tasks

## Badge Setup Note

If you rename your GitHub repo or owner, update badge/action links in this README:
- `JesseRod329/anaj-agency-os`
