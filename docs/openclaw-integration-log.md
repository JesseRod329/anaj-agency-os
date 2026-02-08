# ANAJ ↔ OpenClaw Integration Log

## Contracts (Slice 0 Baseline)

### Command Envelope

```json
{
  "type": "command",
  "id": "uuid",
  "command": "navigate",
  "params": {},
  "idempotencyKey": "optional-key",
  "sentAt": "ISO-8601"
}
```

### Command Ack Envelope

```json
{
  "type": "ack",
  "id": "uuid",
  "requestId": "uuid",
  "status": "completed|failed|duplicate",
  "command": "navigate",
  "result": {},
  "error": null,
  "sentAt": "ISO-8601"
}
```

### Event Envelope

```json
{
  "type": "event",
  "event": "project.created",
  "entity": "project",
  "entityId": "uuid",
  "payload": {},
  "version": 1,
  "sentAt": "ISO-8601"
}
```

## Push Log Format

For each slice append:

```text
## Slice N - <name>
- Commit: <sha>
- Push: origin codex/openclaw-full-control
- PR: <url or pending>
- Validation:
  - <command>
  - <result>
- Notes:
  - <important behavior/risk>
```

## Baseline Checkpoint

- Status: initialized
- Scope: existing dirty workspace + contracts scaffold

## Slice 0 - Baseline checkpoint and contracts
- Commit: `1ee5300`
- Push: `origin codex/openclaw-full-control`
- PR: https://github.com/JesseRod329/anaj-agency-os/pull/2
- Validation:
  - `git push -u origin codex/openclaw-full-control`
  - Branch created and tracking remote.
- Notes:
  - DMG artifact intentionally excluded from git history.

## Slice 1 - Realtime WebSocket foundation
- Commit: this slice commit (`feat: add websocket hub for realtime openclaw bridge`)
- Push: `origin codex/openclaw-full-control`
- PR: https://github.com/JesseRod329/anaj-agency-os/pull/2
- Validation:
  - `xcodebuild -project /Users/jesse/anaj1/anaj/anaj.xcodeproj -scheme anaj -destination "platform=macOS" build`
  - BUILD SUCCEEDED.
- Notes:
  - Added dedicated WebSocket listener on `18791` with handshake/auth/heartbeat.
  - Added typed command/ack/event envelopes and command execution acknowledgements.
