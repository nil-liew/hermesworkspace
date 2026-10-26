#!/usr/bin/env bash
# Fresh-start Open Intelligent UI + Laya engine
# Usage: ./scripts/oiui-start.sh
set -e

echo "=== Open Intelligent UI + Laya Engine ==="

# 1. Kill stale processes
echo "→ Cleaning up stale processes..."
lsof -ti:8420 | xargs kill -9 2>/dev/null || true
lsof -ti:8123 | xargs kill -9 2>/dev/null || true
lsof -ti:3000  | xargs kill -9 2>/dev/null || true
sleep 1

# 2. Get token from keychain
TOKEN=$(security find-generic-password -s laya-engine -w 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not read Laya engine token from keychain"
  exit 1
fi
echo "→ Token: ${TOKEN:0:8}...${TOKEN: -4}"

# 3. Verify .env token matches
ENV_TOKEN=$(grep ROUTING_AUTH_TOKEN ~/hermesworkspace/OpenIntelligentUI/apps/agent/.env | cut -d= -f2)
if [ "$ENV_TOKEN" != "$TOKEN" ]; then
  echo "→ Fixing .env token mismatch..."
  sed -i '' "s/ROUTING_AUTH_TOKEN=.*/ROUTING_AUTH_TOKEN=$TOKEN/" \
    ~/hermesworkspace/OpenIntelligentUI/apps/agent/.env
  echo "   Updated .env"
fi

# 4. Start Laya engine (background)
echo "→ Starting Laya engine (:8420)..."
cd ~/hermesworkspace/laya/engine
LAYA_ENGINE_TOKEN="$TOKEN" .venv/bin/python -m laya.main > /tmp/laya-engine.log 2>&1 &
LAYA_PID=$!
echo "   PID: $LAYA_PID"

# Wait for Laya to be healthy
for i in $(seq 1 10); do
  if curl -sf http://127.0.0.1:8420/health > /dev/null 2>&1; then
    echo "   Laya engine healthy ✓"
    break
  fi
  if [ $i -eq 10 ]; then
    echo "ERROR: Laya engine failed to start"
    kill $LAYA_PID 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# Test router
echo "→ Testing router..."
ROUTER_TEST=$(curl -s -X POST http://127.0.0.1:8420/route/visual \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}')
echo "   Response: $ROUTER_TEST"

# 5. Start OIUI (foreground — this blocks until you Ctrl+C)
echo ""
echo "→ Starting Open Intelligent UI..."
echo "   App: http://localhost:3000"
echo "   Agent: http://localhost:8123"
echo "   MCP: http://localhost:3100"
echo "   Press Ctrl+C to stop"
echo ""
cd ~/hermesworkspace/OpenIntelligentUI
make dev
