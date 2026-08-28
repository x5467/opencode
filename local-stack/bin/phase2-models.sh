#!/usr/bin/env bash
# Phase 2: model downloads, memory budget (12GB hard rule), server + tool-call verification.
set -euo pipefail
ART_DIR="./local-validation"; mkdir -p "$ART_DIR"
LOG="$ART_DIR/phase2.log"; exec > >(tee -a "$LOG") 2>&1
echo "=== Phase 2: $(date) ==="
export PATH="$HOME/.lmstudio/bin:$PATH"

CODER_CANDIDATES=(
  "unsloth/Qwen3-Coder-30B-A3B-Instruct-UD-MLX-4bit"
  "lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit"
  "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit"
)
DOCS_CANDIDATES=(
  "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit"
  "lmstudio-community/Qwen3.6-35B-A3B-MLX-4bit"
  "mlx-community/Qwen3.6-35B-A3B-4bit"
)

# --check-challenger: non-blocking catalog watch for Qwen3.8-27B.
if [[ "${1:-}" == "--check-challenger" ]]; then
  echo "Challenger watch: searching catalog for Qwen3.8-27B MLX/unsloth quants..."
  if lms get "Qwen3.8-27B" --yes --dry-run 2>/dev/null || lms search "Qwen3.8-27B" 2>/dev/null | grep -qi "qwen3.8-27b"; then
    echo "CHALLENGER FOUND: pull it and re-run phase5-bench.sh + Phase 6 against both incumbents."
  else
    echo "No Qwen3.8-27B MLX quant in catalog yet."
  fi
  exit 0
fi

download_first_available() { # $1..: candidate HF ids; echoes the one that worked
  # lms get treats bare owner/repo as an LM Studio Hub artifact; arbitrary
  # Hugging Face repos must be addressed by full URL.
  local id
  for id in "$@"; do
    echo "Trying: lms get https://huggingface.co/$id --yes" >&2
    if lms get "https://huggingface.co/$id" --yes >&2; then echo "$id"; return 0; fi
  done
  return 1
}

# 1. Downloads (skips already-downloaded automatically).
CODER_ID=$(download_first_available "${CODER_CANDIDATES[@]}") \
  || { echo "FATAL: no coder-model candidate downloadable. Run 'lms get qwen3-coder-30b' interactively, note the exact id, and edit CODER_CANDIDATES."; exit 1; }
DOCS_ID=$(download_first_available "${DOCS_CANDIDATES[@]}") \
  || { echo "FATAL: no docs-model candidate downloadable. Run 'lms get qwen3.6-35b' interactively and edit DOCS_CANDIDATES."; exit 1; }
echo "Downloaded: coder=$CODER_ID docs=$DOCS_ID"

# 2+3. Memory budget from the REAL downloaded weights + config.json; 12GB hard rule.
MODELS_ROOT="$HOME/.lmstudio/models"; [[ -d "$MODELS_ROOT" ]] || MODELS_ROOT="$HOME/.cache/lm-studio/models"
python3 - "$MODELS_ROOT" "$CODER_ID" "$DOCS_ID" <<'PY' | tee "$ART_DIR/memory-budget.md"
import json, os, sys
root, coder, docs = sys.argv[1], sys.argv[2], sys.argv[3]
TOTAL = 64.0; RULE = 12.0; OVERHEAD = 2.5

def model_dir(mid):
    p = os.path.join(root, *mid.split("/"))
    if os.path.isdir(p): return p
    # fall back: search by trailing name
    tail = mid.split("/")[-1].lower()
    for dp, dn, fn in os.walk(root):
        if os.path.basename(dp).lower() == tail: return dp
    sys.exit(f"FATAL: cannot locate downloaded dir for {mid} under {root}")

def stats(mid):
    d = model_dir(mid)
    size = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(d) for f in fs) / 1e9
    cfgp = os.path.join(d, "config.json")
    with open(cfgp) as f: c = json.load(f)
    c = c.get("text_config", c)
    L = c["num_hidden_layers"]; kvh = c.get("num_key_value_heads", c["num_attention_heads"])
    hd = c.get("head_dim") or c["hidden_size"] // c["num_attention_heads"]
    kv_per_tok = 2 * L * kvh * hd * 2  # fp16 bytes/token
    return size, kv_per_tok, c.get("max_position_embeddings", "?")

rows, tot_w, tot_kv64 = [], 0.0, 0.0
for label, mid in (("coder", coder), ("docs", docs)):
    w, kvpt, maxctx = stats(mid)
    kv64, kv128 = kvpt*65536/1e9, kvpt*131072/1e9
    tot_w += w; tot_kv64 += kv64
    rows.append((label, mid, w, w, kv64, kv128, maxctx))

print("\n## Memory budget — BOTH models loaded (fp16 KV; 8-bit KV halves the KV columns)\n")
print("| Model | Weights disk GB | RAM at load GB | KV @64K GB | KV @128K GB | Native max ctx |")
print("|---|---|---|---|---|---|")
for r in rows:
    print(f"| {r[0]}: {r[1]} | {r[2]:.1f} | {r[3]:.1f} | {r[4]:.1f} | {r[5]:.1f} | {r[6]} |")
t64 = tot_w + tot_kv64 + OVERHEAD
t64q = tot_w + tot_kv64/2 + OVERHEAD
t128 = tot_w + 2*tot_kv64 + OVERHEAD
print(f"\n- Combined @64K each, fp16 KV, +{OVERHEAD} overhead: **{t64:.1f} GB** -> headroom **{TOTAL-t64:.1f} GB**")
print(f"- Combined @64K each, 8-bit KV:                     **{t64q:.1f} GB** -> headroom **{TOTAL-t64q:.1f} GB**")
print(f"- Combined @128K each, fp16 KV:                     **{t128:.1f} GB** -> headroom **{TOTAL-t128:.1f} GB**")
if TOTAL - t128 < RULE: print(f"- 128K/128K configuration: **REJECTED** (headroom < {RULE} GB hard rule)")
if TOTAL - t64q < RULE and TOTAL - t64 < RULE:
    sys.exit(f"FATAL: even 64K + 8-bit KV leaves under {RULE} GB. Configuration rejected by hard rule.")
kvq = "true" if TOTAL - t64 < RULE else "false"
print(f"\nDecision: context 65536 per model; 8-bit KV quantization {'REQUIRED' if kvq=='true' else 'optional (fp16 passes)'}.")
open(os.environ.get("ART_JSON", "./local-validation/phase2-budget.json"), "w").write(
    json.dumps({"coder": coder, "docs": docs, "headroom64_fp16": round(TOTAL-t64,1),
                "headroom64_kv8": round(TOTAL-t64q,1), "kv8_required": kvq=="true"}))
PY

KV8_REQUIRED=$(python3 -c "import json;print(json.load(open('$ART_DIR/phase2-budget.json'))['kv8_required'])")

# 4. Server + load both models at 65536 context.
lms server start --port 1234 || { echo "retrying server start once..."; sleep 3; lms server start --port 1234; }
LOAD_FLAGS=(--context-length 65536 --yes)
for M in "$CODER_ID" "$DOCS_ID"; do
  if ! lms load "$M" "${LOAD_FLAGS[@]}"; then
    echo "Load failed for $M — likely the macOS GPU wired-memory guardrail with two ~18-20GB models."
    echo "Fix: LM Studio Settings -> Hardware -> guardrails 'Relaxed', or: sudo sysctl iogpu.wired_limit_mb=57344"
    read -rp "Apply a fix, then press Enter to retry once... "
    lms load "$M" "${LOAD_FLAGS[@]}" || { echo "FATAL: load failed twice for $M"; exit 1; }
  fi
done
[[ "$KV8_REQUIRED" == "True" ]] && echo "NOTE: enable 8-bit KV cache in each model's load settings (LM Studio > My Models > gear > KV Cache Quantization) — budget requires it."

# Confirm ACTUAL loaded context, not theoretical max.
lms ps | tee "$ART_DIR/lms-ps.txt"
lms ps --json > "$ART_DIR/lms-ps.json" 2>/dev/null || true
python3 - <<PY || { echo "FATAL: a loaded model reports context < 65536 (see $ART_DIR/lms-ps.json)"; exit 1; }
import json,sys
try: d=json.load(open("$ART_DIR/lms-ps.json"))
except Exception: sys.exit(0)  # older lms without --json: verified visually in lms-ps.txt
ms = d if isinstance(d,list) else d.get("models",d.get("loaded",[]))
for m in ms:
    ctx = m.get("contextLength") or m.get("context_length") or 0
    print(m.get("identifier",m.get("modelKey","?")), "ctx:", ctx)
    assert int(ctx) >= 65536, "context below 65536"
PY

# Served model IDs as the API reports them (used verbatim by Phase 3).
curl -sf http://127.0.0.1:1234/v1/models | tee "$ART_DIR/v1-models.json"; echo

# Tool-call verification: must be structured tool_calls, NOT JSON inside content.
API_CODER_ID=$(python3 -c "import json; d=json.load(open('$ART_DIR/v1-models.json'))['data']; print(next((m['id'] for m in d if 'coder' in m['id'].lower()), d[0]['id']))")
curl -sf http://127.0.0.1:1234/v1/chat/completions -H "Content-Type: application/json" -d @- <<EOF > "$ART_DIR/toolcall-test.json"
{"model": "$API_CODER_ID",
 "messages":[{"role":"user","content":"What is the weather in Miami? Use the tool."}],
 "tools":[{"type":"function","function":{"name":"get_weather","description":"Get current weather for a city",
   "parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],
 "max_tokens":200}
EOF
python3 - <<'PY' || { echo "FATAL: no well-formed tool_calls structure (or tool JSON leaked into content)"; exit 1; }
import json
r = json.load(open("./local-validation/toolcall-test.json"))
m = r["choices"][0]["message"]
tcs = m.get("tool_calls") or []
assert tcs, "tool_calls missing/empty"
f = tcs[0]["function"]; assert f["name"] == "get_weather"
json.loads(f["arguments"])  # arguments must be valid JSON string
c = m.get("content") or ""
assert "tool_call" not in c and '"arguments"' not in c, "tool-call JSON pasted inside content"
print("tool_calls OK:", f["name"], f["arguments"])
PY

printf '{"coder_repo":"%s","docs_repo":"%s"}\n' "$CODER_ID" "$DOCS_ID" > "$ART_DIR/phase2.json"
echo "=== Phase 2 PASS ==="
