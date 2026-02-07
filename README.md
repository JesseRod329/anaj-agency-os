# ANAJ Agency OS

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-0A84FF)](#)
[![Swift](https://img.shields.io/badge/swift-5.0%2B-F05138)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/JesseRod329/anaj-agency-os/ci.yml?label=CI)](https://github.com/JesseRod329/anaj-agency-os/actions)
[![Issues](https://img.shields.io/github/issues/JesseRod329/anaj-agency-os)](https://github.com/JesseRod329/anaj-agency-os/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./.github/CONTRIBUTING.md)

> [!IMPORTANT]
> ## ATTENTION: LOCAL-USE OPEN SOURCE PROGRAM
> ANAJ is an open-source, local-first Agency OS intended for self-hosted/local workflows.
> It includes integration surfaces for OpenClaw orchestration and external LLM providers (Ollama, OpenAI, Google Gemini).
> Treat current integrations as production-capable for local use, with cloud-first hosted deployment patterns still evolving.

ANAJ Agency OS is a SwiftUI + SwiftData workspace for agency operations: clients, projects, tasks, notes, prompt workflows, insights, invoicing, and ledger reporting.

## What This Repo Is / Is Not

**This repo is:**
- A full local-first macOS/iOS agency operating system.
- Open-source codebase with a built-in local API for OpenClaw and automation.
- Multi-provider AI workspace (Ollama/OpenAI/Gemini) with Prompt Studio + Insights.

**This repo is not:**
- A hosted SaaS product with managed cloud infrastructure.
- A one-click managed OpenClaw deployment.
- A guarantee of cloud sync/collaboration behavior in every environment.

## Why ANAJ

- Agency-first data model (clients, projects, tasks, invoices, notes)
- Unified command center UX across macOS and iOS
- Built-in Prompt Studio for AI-assisted planning and insight capture
- Local API bridge for external tools and automations (`/api/*`)
- Cloud-ready structure with CloudKit support

## Core Features

### AI + Prompt Studio

- Multi-provider AI chat with runtime switching:
  - `Open Source` (Ollama local models)
  - `OpenAI` (`gpt-4o`)
  - `Google` (Gemini)
- Local model discovery via Ollama `/tags` and configurable Ollama base URL.
- Streaming chat for local models (token-by-token UI updates).
- Attachment-aware prompting:
  - PDF/text/source file ingestion
  - Image attachment support (base64 payloads for multimodal prompts)
- Built-in system prompt editor + reusable persona presets (SwiftUI Expert, UX Designer, Tech Lead, Copywriter, Data Analyst, Troubleshooter).
- Optional project-context injection into prompts (active tasks, project/client status).
- AI summary generation from full chat history and one-click save as structured insight.
- Manual insight capture directly from any chat message.
- Rich message rendering with markdown/code block parsing and copy/save controls.

### Ollama + Note Intelligence

- Hybrid note extraction pipeline:
  - Apple NaturalLanguage + `NSDataDetector` for fast local entity extraction
  - Ollama fallback pass for task/decision extraction
- Extracted entity suggestions for:
  - People/client mentions
  - Project associations
  - Tasks
  - Decisions
  - Deadlines
  - Budget/cost values
- Accept/dismiss workflow for extracted entities with direct object creation in ANAJ.

### Insights System

- Dedicated Insights workspace with 3-panel workflow:
  - Intelligence index
  - Searchable insight feed
  - Inspector detail panel
- Insight filtering by:
  - Starred
  - Project
  - Insight type
- Insight metadata tracking:
  - Source (`AI summary`, `manual selection`, etc.)
  - Linked project/prompt
  - Provider label
  - Source message references

### Agency Operations

- Agency-native data model:
  - Clients
  - Projects
  - Tasks
  - Notes
  - Decisions
  - Tags
  - Activities
- Inbox/project task workflows with priority, estimates, actuals, due dates, and status.
- Archive and restore flows for records.
- Activity Feed timeline with filters + search.
- Global Search (`Cmd+K`) across projects/clients/notes/tasks/decisions.
- Command menu for fast lookup/jump actions.
- Menu bar quick-add widget for task/note/project capture.
- Rich text editing support for notes/content.

### Finance + Delivery

- Agency ledger with profitability and invoice tabs.
- Profitability analytics:
  - Revenue
  - Net profit
  - Margin
  - Per-project cost/profit visualization
- Invoice workflows:
  - Status handling (`draft`, `sent`, `paid`, `overdue`, etc.)
  - Outstanding vs paid tracking
  - Invoice list + summary cards
- Project-level financial modeling (internal rate, hours, costs, budget).

### Integrations + Automation Surface

- Built-in localhost API server for external orchestration (OpenClaw-ready):
  - `GET /api/health`
  - `GET /api/clients`
  - `POST /api/clients`
  - `GET /api/projects`
  - `POST /api/projects`
  - `GET /api/tasks`
  - `POST /api/tasks`
  - `PATCH /api/tasks/:id`
  - `POST /api/notes`
  - `GET /api/ledger`
  - `POST /api/notify`
  - `POST /api/openclaw/webhook`
  - `POST /api/commands/execute`
  - `GET /api/events/stream`
  - `POST /api/memory/sync`
  - `GET /api/memory/changes`
  - `POST /api/agents/run`
  - `GET /api/agents/runs/:id`
- Optional API key auth via `ANAJ_API_KEY` environment variable.
- Local task reminder scheduling via UserNotifications.
- Calendar integration via EventKit (task + calendar event views).

### Data, Reliability, and Platform

- SwiftData-backed relational schema with strong model links across agency entities.
- JSON backup/export manager (auto-cleanup + backup history retention).
- Cross-platform target structure (`macOS` + `iOS` views).
- CloudKit scaffolding + capability guards for cloud-enabled deployments.

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
├── .github/               # CI + community health files
└── docs/                  # Supporting docs (CloudKit setup, support notes)
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

## Local API

The app starts a local API server when ANAJ launches:

- Base URL: `http://127.0.0.1:18790`
- Health: `GET /api/health`
- Endpoints:
  - `GET /api/health`
  - `GET /api/clients`
  - `POST /api/clients`
  - `GET /api/projects`
  - `POST /api/projects`
  - `GET /api/tasks`
  - `POST /api/tasks`
  - `PATCH /api/tasks/:id`
  - `POST /api/notes`
  - `GET /api/ledger`
  - `POST /api/notify`

The API contract is evolving with the OpenClaw integration roadmap in this repository.

## Open Source

- [Contributing Guide](./.github/CONTRIBUTING.md)
- [Code of Conduct](./.github/CODE_OF_CONDUCT.md)
- [Security Policy](./.github/SECURITY.md)
- [Support](./docs/support.md)
- [Docs Index](./docs/README.md)
- [CloudKit Setup Notes](./docs/cloudkit-setup.md)
- [License](./LICENSE)

## Roadmap (High Level)

- Prompt Studio provider expansion (OpenClaw provider)
- OpenClaw command execution and event stream wiring
- Memory sync and agent-run observability
- Notification bridge for external channels
- Memory sync across AI + notes context
- Agent-driven workflows for specialized tasks

## Badge Setup Note

If you rename your GitHub repo or owner, update badge/action links in this README:
- `JesseRod329/anaj-agency-os`
