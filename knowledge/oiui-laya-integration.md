---
type: playbook
title: OpenIntelligentUI + Laya decision-engine integration
description: Run CopilotKit OpenIntelligentUI with agnes chat model and Laya engine as the presentation router
updated: 2026-10-14
---

# OpenIntelligentUI + Laya as Decision Engine

Runs [OpenIntelligentUI](https://github.com/CopilotKit/OpenIntelligentUI) (~/hermesworkspace/OpenIntelligentUI) with the **agnes-3.0-flash** chat model and the **Laya engine** (~/hermesworkspace/laya) acting as the presentation decision engine (replaces Ollama/Jev router).

## Architecture

```
OIUI app (Next.js, :3000)
  -> OIUI agent (Python, :8123)
       chat model   = agnes-3.0-flash via https://apihub.agnes-ai.com/v1 (OPENAI_BASE_URL)
       router        = POST http://127.0.0.1:8420/route/visual (Laya engine, Bearer token)
                        -> Laya llm_call(role=router) = agnes/agnes-3.0-flash
                        -> returns Ollama-shaped {"message":{"content": "{\"choice\":...}"}}
```

## Laya side (upstream repo — local modifications)

1. `engine/laya/api/visual_route_api.py` (new): `POST /route/visual`, Ollama-compatible
   request, answers `{"choice","confidence"}` via `llm_call(role="router", response_schema)`.
2. `engine/laya/main.py`: import + `app.include_router(visual_route_router, dependencies=auth_deps)`.
3. `~/.laya/settings.json`: custom provider `agnes` (openai_compatible,
   base_url `https://apihub.agnes-ai.com` — bare host; Laya appends `/v1`),
   key in OS keychain `custom_agnes` (copied from `HERMES_CUSTOM_APIHUB_AGNES_AI_COM_API_KEY`),
   `models.router = "agnes/agnes-3.0-flash"`.
   **Pitfall:** Agnes proxy rejects native `response_format=json_schema`
   ("missing field name") — provider must set `capabilities_override.supports_structured_output=false`
   so Laya falls back to JSON-in-content prompting (its `_extract_json` recovers it).

## OIUI side (upstream repo — local modifications)

1. `apps/agent/src/model.py`: `build_model` now accepts any model name when
   `OPENAI_BASE_URL` is set (upstream only allowed gpt-*/claude-*/chat-latest).
2. `apps/agent/src/visualization_router.py`: `ROUTING_AUTH_TOKEN` env + `Authorization: Bearer`
   header on the router call.
3. `apps/agent/.env`: OPENAI_API_KEY (agnes key), OPENAI_BASE_URL, LLM_MODEL=agnes-3.0-flash,
   OLLAMA_ROUTING_URL=http://127.0.0.1:8420/route/visual, ROUTING_AUTH_TOKEN=dev-oiui-router-token.
4. `packages/design-system/dist/` must be built: `pnpm --filter @repo/design-system build`
   (app 500s with "Module not found: @repo/design-system" if it's missing).

## Run

```bash
# Laya engine (token can also be minted in keychain; env var overrides)
cd ~/hermesworkspace/laya/engine && LAYA_ENGINE_TOKEN=dev-oiui-router-token .venv/bin/python -m laya.main
# OIUI
cd ~/hermesworkspace/OpenIntelligentUI && make dev   # app :3000, agent :8123
```

Verify: `curl http://localhost:8123/health`, `curl http://127.0.0.1:8420/health`,
POST /route/visual with the Bearer token. E2E-verified 2026-10-14: full agent
`ainvoke` for "compare car types in a table" → Laya decided `{"renderer":"a2ui",
"visualization":"table"}` and agnes answered with a markdown table. Note: a full
agent turn takes 60-120s (slow but functional).

## OIUI BYOK-gate bypass (server keys already configured)

The app ships in "BYOK" mode: `hasKeys` starts false and only flips when a user
manually pastes keys, so it always shows "Add your OpenAI and Jev API keys to
start" even when `.env` has shared keys. Fix added (all in OIUI, upstream repo):
- `apps/agent/main.py`: `GET /credentials/status` → `{"server_configured": bool}`
  (reuses `server_credentials_available()`).
- `apps/app/src/app/api/credentials-status/route.ts`: Next.js proxy to that endpoint.
- `apps/app/src/components/chat/provider-keys.tsx`: `useEffect` fetches
  `/api/credentials-status`; when true, sets `serverConfigured` and
  `hasKeys = keys !== null || serverConfigured` — **no placeholder headers sent**,
  so the agent falls back to its server-side `.env` config (agnes + Laya router).
- Test updated: `provider-keys.test.tsx` "aborts pending validation" now finds
  the `/api/provider-keys` call specifically (the provider's detection fetch was
  counted as call[0] before).

Verify: `curl http://localhost:8123/credentials/status` → `{"server_configured":true}`

## Fresh-Start Procedure (copy-paste)

```bash
# Kill stale processes
lsof -ti:8420 | xargs kill -9 2>/dev/null || true
lsof -ti:8123 | xargs kill -9 2>/dev/null || true
lsof -ti:3000  | xargs kill -9 2>/dev/null || true

# Get token from keychain
TOKEN=$(security find-generic-password -s laya-engine -w)

# Verify OIUI .env matches (should show the same token)
grep ROUTING_AUTH_TOKEN ~/hermesworkspace/OpenIntelligentUI/apps/agent/.env

# Start Laya engine FIRST
cd ~/hermesworkspace/laya/engine && \
  LAYA_ENGINE_TOKEN=$TOKEN .venv/bin/python -m laya.main &
sleep 3 && curl http://127.0.0.1:8420/health

# Start OIUI SECOND
cd ~/hermesworkspace/OpenIntelligentUI && make dev
```

Open preview → `http://localhost:3000`

## Pitfalls
