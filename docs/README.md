# Documentation Index

This folder contains operational and contributor-facing documentation for ANAJ Agency OS.

## Core Docs

- `cloudkit-setup.md`: CloudKit capability and sync setup notes.
- `support.md`: Support channel and issue reporting guidance.

## OpenClaw + LLM Integration Notes

- ANAJ runs a local API at `http://127.0.0.1:18790` for external orchestration.
- ANAJ exposes a realtime WebSocket endpoint at `ws://127.0.0.1:18791/ws/openclaw`.
- OpenClaw bridge service runs at `http://127.0.0.1:18890`.
- Current integration endpoints include:
  - `POST /api/openclaw/webhook`
  - `POST /api/commands/execute`
  - `GET /api/events/stream`
  - `POST /api/memory/sync`
  - `GET /api/memory/changes`
  - `POST /api/agents/run`
  - `GET /api/agents/runs/:id`

## Repository Hygiene

- Root should remain code-forward:
  - App source: `anaj/`
  - Project: `anaj.xcodeproj/`
  - Tests: `anajTests/`, `anajUITests/`
- Generated artifacts must not be committed (`build/`, DerivedData, user data files).
## Integration Execution Log

- `openclaw-integration-log.md`: slice-by-slice implementation/push history and WebSocket command/event contracts.

## Operator Checklist

- Start ANAJ app to bring up API and WebSocket listeners.
- In Prompt Studio OpenClaw settings, use bridge URL `http://127.0.0.1:18890`.
- If auth is enabled, set matching `ANAJ API Key` in app settings and bridge environment.
- For method errors, use `Allow` response header to correct request verb.
