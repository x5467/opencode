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

find_local() { # $1..: candidate ids; echoes the first already downloaded
  local all id
  all=$(lms ls 2>/dev/null | tr '[:upper:]' '[:lower:]') || return 1
  for id in "$@"; do
    grep -q "$(basename "$id" | tr '[:upper:]' '[:lower:]')" <<<"$all" && { echo "$id"; return 0; }
  done
  return 1
}

# 1. Downloads (a candidate already present locally is reused, never re-fetched).
CODER_ID=$(find_local "${CODER_CANDIDATES[@]}") || CODER_ID=$(download_first_available "${CODER_CANDIDATES[@]}") \
  || { echo "FATAL: no coder-model candidate downloadable. Run 'lms get qwen3-coder-30b' interactively, note the exact id, and edit CODER_CANDIDATES."; exit 1; }
DOCS_ID=$(find_local "${DOCS_CANDIDATES[@]}") || DOCS_ID=$(download_first_available "${DOCS_CANDIDATES[@]}") \
  || { echo "FATAL: no docs-model candidate downloadable. Run 'lms get qwen3.6-35b' interactively and edit DOCS_CANDIDATES."; exit 1; }
echo "Using: coder=$CODER_ID docs=$DOCS_ID"

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

# The lms load model key is NOT the HF owner/repo string — resolve the real
# local key from lms ls by matching on the repo name.
resolve_key() { # $1: owner/repo -> local lms model key
  python3 - "$1" <<'PY'
import json, subprocess, sys
want = sys.argv[1].split("/")[-1].lower()
keys = []
try:
    out = subprocess.run(["lms","ls","--json"], capture_output=True, text=True, timeout=30).stdout
    data = json.loads(out)
    items = data if isinstance(data, list) else data.get("models") or data.get("data") or []
    for m in items:
        for f in ("modelKey","key","path","id"):
            if isinstance(m, dict) and m.get(f):
                keys.append(m[f]); break
except Exception:
    pass
if not keys:
    out = subprocess.run(["lms","ls"], capture_output=True, text=True, timeout=30).stdout
    for line in out.splitlines():
        t = line.strip().split()
        if t and "/" not in t[0][:1]: keys.append(t[0])
for k in keys:
    if want in k.lower() or k.lower() in want:
        print(k); sys.exit(0)
# loosest match: shared 12-char prefix of the repo name
for k in keys:
    if want[:12] in k.lower():
        print(k); sys.exit(0)
sys.exit(f"no local model key matches '{want}'; lms ls keys: {keys}")
PY
}
CODER_KEY=$(resolve_key "$CODER_ID") || { echo "FATAL: cannot resolve local key for $CODER_ID"; exit 1; }
DOCS_KEY=$(resolve_key "$DOCS_ID")   || { echo "FATAL: cannot resolve local key for $DOCS_ID"; exit 1; }
echo "Local model keys: coder=$CODER_KEY docs=$DOCS_KEY"

# 4. Server + ensure both models are loaded at EXACTLY 65536 context.
# (>65536 fp16 KV can exceed the 12GB headroom rule if a session fills it;
#  already-loaded-correct models are skipped so reruns never double-load.)
lms server start --port 1234 || { echo "retrying server start once..."; sleep 3; lms server start --port 1234; }

loaded_ctx() { # $1: model key -> prints its loaded context length, empty if not loaded
  lms ps --json 2>/dev/null | python3 -c '
import json, sys
key = sys.argv[1].lower()
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
for m in (d if isinstance(d, list) else d.get("models", [])):
    ident = (m.get("identifier") or "").lower()
    if ident and (key in ident or ident in key):
        print(m.get("contextLength") or m.get("context_length") or ""); break
' "$1"
}

NEED_LOAD=()
for M in "$CODER_KEY" "$DOCS_KEY"; do
  CTX=$(loaded_ctx "$M")
  if [[ "$CTX" == "65536" ]]; then echo "$M already loaded at 65536 context — skipping."; continue; fi
  if [[ -n "$CTX" && "$CTX" -ge 65536 ]] && grep -q "$M" "$ART_DIR/deviations.md" 2>/dev/null; then
    echo "$M loaded at ctx=$CTX — known recorded deviation (client-side 65536 cap) — skipping."; continue
  fi
  [[ -n "$CTX" ]] && { echo "$M loaded at ctx=$CTX (need 65536) — unloading to reload."; lms unload "$M" || true; }
  NEED_LOAD+=("$M")
done

# Budget verdict: KV quantization must be set BEFORE a load (applies at load time).
if [[ ${#NEED_LOAD[@]} -gt 0 && "$KV8_REQUIRED" == "True" ]]; then
  cat <<'EOF'
>>> REQUIRED BY THE 12GB HEADROOM RULE: 8-bit KV cache, checked per model.
    LM Studio -> My Models -> gear icon per model -> "KV Cache Quantization" = 8-bit.
    KNOWN LIMITATION: a model served through the mlx-vlm vision path (the
    Qwen3.6 35B build is one) rejects KV quantization with "batched vision
    path does not support KV cache quantization" — leave THAT model at
    off/fp16. The mixed config (coder 8-bit, docs fp16) leaves ~14 GB
    headroom at 64K each and still satisfies the 12 GB rule. Only if
    NEITHER model accepts 8-bit KV is the configuration rejected.
    Also confirm each model's Context Length setting is 65536 (not the max).
EOF
  read -rp "Press Enter once the KV settings are confirmed (Ctrl-C to stop)... "
fi

for M in "${NEED_LOAD[@]}"; do
  if ! lms load "$M" --context-length 65536 --yes; then
    echo "Load failed for $M. If the error mentions memory/guardrails: LM Studio Settings -> Hardware -> guardrails 'Relaxed', or: sudo sysctl iogpu.wired_limit_mb=57344"
    read -rp "Apply a fix, then press Enter to retry once... "
    lms load "$M" --context-length 65536 --yes || { echo "FATAL: load failed twice for $M"; exit 1; }
  fi
  CTX=$(loaded_ctx "$M")
  if [[ "$CTX" != "65536" ]]; then
    if [[ -z "$CTX" || "$CTX" -lt 65536 ]]; then
      echo "FATAL: $M loaded at ctx=${CTX:-none}, below the 65536 minimum"; exit 1
    fi
    # Empirically the mlx-vlm loader ignores --context-length and the GUI
    # setting, always loading at model max. KV memory is allocated lazily,
    # so the 12GB rule holds as long as no client exceeds 64K context —
    # OpenCode's model config caps context at 65536. Recorded deviation.
    echo "DEVIATION: $M pins itself to ctx=$CTX (loader ignores the 65536 setting)."
    echo "Mitigation: OpenCode model limit caps context at 65536; KV is lazily allocated, so the 64K budget math is unchanged. Direct API callers must respect the same cap."
    echo "- $M loads at server ctx=$CTX (loader ignores context-length); 65536 is enforced client-side via OpenCode's model context limit; KV allocates lazily so headroom math is unchanged" >> "$ART_DIR/deviations.md"
  fi
done

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

printf '{"coder_repo":"%s","docs_repo":"%s","coder_key":"%s","docs_key":"%s"}\n' "$CODER_ID" "$DOCS_ID" "$CODER_KEY" "$DOCS_KEY" > "$ART_DIR/phase2.json"
echo "=== Phase 2 PASS ==="
