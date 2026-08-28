#!/usr/bin/env bash
# Phase 5: real generation speed — 500-token completion with a ~30K-token prompt
# loaded, per model, via streaming (prefill excluded from the tok/s figure).
# Gate: >= 20 tok/s per model. On fail: log thermals + memory pressure, report, stop.
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.lmstudio/bin:$PATH"
ART_DIR="./local-validation"; mkdir -p "$ART_DIR"
LOG="$ART_DIR/phase5.log"; exec > >(tee -a "$LOG") 2>&1
echo "=== Phase 5: $(date) ==="

MODELS=$(curl -sf http://127.0.0.1:1234/v1/models | python3 -c "import json,sys;[print(m['id']) for m in json.load(sys.stdin)['data']]")
GATE_FAIL=0
for MODEL in $MODELS; do
  echo "--- Benchmarking $MODEL ---"
  TPS=$(python3 - "$MODEL" <<'PY'
import json, sys, time, urllib.request
model = sys.argv[1]
# ~30K tokens of prompt: repeated technical prose, ~4 chars/token.
chunk = ("The dispatcher acquires the ledger mutex, snapshots the queue depth, "
         "recomputes the drain interval from the moving average, and releases it "
         "before scheduling the next flush cycle across worker shards. ")
prompt = chunk * 640  # ~120K chars ~= 30K tokens
body = json.dumps({"model": model, "stream": True,
    "messages": [{"role": "user", "content": prompt + "\n\nSummarize the above mechanism in detail."}],
    "max_tokens": 500, "temperature": 0.2}).encode()
req = urllib.request.Request("http://127.0.0.1:1234/v1/chat/completions", body,
                             {"Content-Type": "application/json"})
t0 = time.time(); first = None; n = 0
with urllib.request.urlopen(req, timeout=1800) as r:
    for line in r:
        line = line.strip()
        if not line.startswith(b"data: ") or line == b"data: [DONE]": continue
        d = json.loads(line[6:])
        if d["choices"] and d["choices"][0].get("delta", {}).get("content"):
            if first is None: first = time.time()
            n += 1
t1 = time.time()
gen = t1 - first if first else 0.001
print(f"chunks={n} prefill={first-t0:.1f}s gen={gen:.1f}s tok/s={n/gen:.1f}", file=sys.stderr)
print(f"{n/gen:.1f}")
PY
) || { echo "FATAL: bench request failed for $MODEL"; exit 1; }
  echo "$MODEL: $TPS tok/s (30K prompt, 500-token completion)"
  echo "{\"model\":\"$MODEL\",\"tps\":$TPS}" >> "$ART_DIR/phase5-tps.jsonl"
  if python3 -c "import sys; sys.exit(0 if float('$TPS') >= 20 else 1)"; then
    echo "PASS (>= 20 tok/s)"
  else
    GATE_FAIL=1
    echo "FAIL (< 20 tok/s) — capturing thermals and memory pressure:"
    pmset -g therm | tee -a "$ART_DIR/phase5-thermals.txt" || true
    sudo powermetrics --samplers thermal -n1 2>/dev/null | tee -a "$ART_DIR/phase5-thermals.txt" || echo "(powermetrics needs sudo; skipped)"
    memory_pressure | tee -a "$ART_DIR/phase5-mempressure.txt" || true
  fi
done
[[ "$GATE_FAIL" == 1 ]] && { echo "=== Phase 5 GATE FAILED — report above; do not proceed to Phase 6 ==="; exit 1; }
echo "=== Phase 5 PASS ==="
