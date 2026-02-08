# Support

## Community Support

- Open a discussion or issue for product questions and usage help.

## Bug Reports

- Use the bug report issue template.
- Include environment, repro steps, and logs/screenshots.

## Security

For vulnerabilities, use the private process in [Security Policy](../.github/SECURITY.md).

## OpenClaw Integration Triage

1. Check ANAJ API health:
   - `curl -s http://127.0.0.1:18790/api/health`
2. Check bridge health:
   - `curl -s http://127.0.0.1:18890/api/health`
3. Verify auth header when API key is configured:
   - `x-anaj-key: <your key>` or `Authorization: Bearer <your key>`
4. If request returns `405 Method Not Allowed`:
   - inspect the `Allow` header and retry with the permitted method.
5. If OpenClaw chat returns `404`:
   - confirm Prompt Studio OpenClaw URL is `http://127.0.0.1:18890` (not `18790`).
6. Check runtime integration logs:
   - `tail -f ~/Library/Logs/ANAJ/openclaw.log`
   - Look for shared `req:<requestId>` values across API and WebSocket entries.
