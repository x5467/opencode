#!/usr/bin/env bash
# Phase 3: OpenCode local-only configuration + round-trip verification.
# Schema verified against OpenCode v1.18.25 source/docs; re-verify locally with:
#   opencode --version   (and https://opencode.ai/config.json if versions diverge)
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.lmstudio/bin:$PATH"
ART_DIR="./local-validation"; mkdir -p "$ART_DIR"
LOG="$ART_DIR/phase3.log"; exec > >(tee -a "$LOG") 2>&1
echo "=== Phase 3: $(date) ==="
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Served model keys: prefer the identifiers phase 2 actually loaded (the /v1/models
# listing also contains unloaded copies and embedding models), verified against the
# live endpoint.
curl -sf http://127.0.0.1:1234/v1/models > "$ART_DIR/v1-models-live.json" || { echo "FATAL: LM Studio server not responding on :1234 — run phase2 first"; exit 1; }
eval "$(python3 - "$ART_DIR/phase2.json" "$ART_DIR/v1-models-live.json" <<'PY'
import json, sys
served = [m["id"] for m in json.load(open(sys.argv[2]))["data"]]
coder = docs = None
try:
    p2 = json.load(open(sys.argv[1]))
    if p2.get("coder_key") in served: coder = p2["coder_key"]
    if p2.get("docs_key") in served: docs = p2["docs_key"]
except Exception:
    pass
llm = [s for s in served if "embed" not in s.lower()]
coder = coder or next(s for s in llm if "coder" in s.lower())
docs = docs or next(s for s in llm if "coder" not in s.lower())
print(f'CODER_ID="{coder}"; DOCS_ID="{docs}"')
PY
)"
echo "Served keys: coder=$CODER_ID docs=$DOCS_ID"

# Write global config (per-user; backs up any existing one, never touches ~/.claude).
CFG_DIR="$HOME/.config/opencode"; CFG="$CFG_DIR/opencode.json"; mkdir -p "$CFG_DIR"
[[ -f "$CFG" ]] && cp "$CFG" "$CFG.bak.$(date +%s)" && echo "Backed up existing $CFG"
sed -e "s|__CODER_ID__|$CODER_ID|g" -e "s|__DOCS_ID__|$DOCS_ID|g" \
  "$SCRIPT_DIR/../config/opencode.json.template" > "$CFG"
echo "Wrote $CFG"

# Cloud lockout check: only lmstudio may be enabled.
opencode providers | tee "$ART_DIR/providers.txt"
if grep -viE "lmstudio|disabled|^\s*$|─|═|name|npm|local" "$ART_DIR/providers.txt" | grep -qiE "anthropic|openai|google|openrouter|copilot"; then
  echo "WARNING: a cloud provider still shows enabled — inspect $ART_DIR/providers.txt and extend disabled_providers."
  exit 1
fi

# 4. Model switching: both models must respond through OpenCode (headless run per model,
#    then verify in-TUI switching manually with /models).
opencode run -m "lmstudio/$CODER_ID" "Reply with exactly: CODER-OK"  | tee "$ART_DIR/switch-coder.txt" | grep -q "CODER-OK" || { echo "FATAL: coder model no response"; exit 1; }
opencode run -m "lmstudio/$DOCS_ID"  "Reply with exactly: DOCS-OK"   | tee "$ART_DIR/switch-docs.txt"  | grep -q "DOCS-OK"  || { echo "FATAL: docs model no response"; exit 1; }
opencode run -m "lmstudio/$CODER_ID" "Reply with exactly: CODER-OK2" | grep -q "CODER-OK2" || { echo "FATAL: switch back to coder failed"; exit 1; }
echo "Model switching OK (coder -> docs -> coder)."

# 5. File-edit round trip through the agent's tools.
RT_DIR=$(mktemp -d); pushd "$RT_DIR" >/dev/null
printf 'alpha\nbeta\ngamma\n' > roundtrip.txt
opencode run -m "lmstudio/$CODER_ID" \
  "Using your file editing tool, edit ./roundtrip.txt: replace the line 'beta' with 'delta'. Change nothing else." || true
popd >/dev/null
if [[ "$(cat "$RT_DIR/roundtrip.txt")" == $'alpha\ndelta\ngamma' ]]; then
  echo "File-edit round trip OK."
else
  echo "FATAL: edit did not land exactly. File contains:"; cat "$RT_DIR/roundtrip.txt"; exit 1
fi
printf '{"coder":"%s","docs":"%s"}\n' "$CODER_ID" "$DOCS_ID" > "$ART_DIR/phase3.json"
echo "=== Phase 3 PASS ===  (also verify /models switching once inside the TUI)"
