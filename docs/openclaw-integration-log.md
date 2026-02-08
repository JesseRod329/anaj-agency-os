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
