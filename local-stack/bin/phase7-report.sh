#!/usr/bin/env bash
# Phase 7: final report, parallel-operation verification, probation log.
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.lmstudio/bin:$PATH"
ART_DIR="./local-validation"; mkdir -p "$ART_DIR"
export PATH="$HOME/.lmstudio/bin:$PATH"
REPORT="$ART_DIR/final-report.md"

# Parallel operation — both stacks must launch independently.
CLAUDE_STATUS="FAIL"; OPENCODE_STATUS="FAIL"
if command -v claude >/dev/null && claude --version >/dev/null 2>&1; then
  echo ">>> Launching 'claude' — confirm it opens a NORMAL CLOUD session (then /exit)."
  claude || true
  read -rp "Did claude open a normal cloud session, untouched by this setup? [y/N] " a
  [[ "${a,,}" == y* ]] && CLAUDE_STATUS="PASS"
else
  # No claude CLI on this machine — Claude is used via the desktop/web app.
  echo ">>> No 'claude' CLI installed. Open the Claude app and confirm it works normally."
  read -rp "Does your Claude app open a normal cloud session, untouched by this setup? [y/N] " a
  [[ "${a,,}" == y* ]] && CLAUDE_STATUS="PASS (via Claude app; no CLI installed on this Mac)"
fi
echo ">>> Launching 'opencode' — confirm the LOCAL session (lmstudio provider, then quit)."
opencode || true
read -rp "Did opencode open the local session against LM Studio? [y/N] " b
[[ "${b,,}" == y* ]] && OPENCODE_STATUS="PASS"

{
echo "# Local LLM Stack — Final Report ($(date))"
echo
echo "## Versions"
echo "- OpenCode: $(opencode --version 2>/dev/null | head -1)  (install cmd: $(python3 -c "import json;print(json.load(open('$ART_DIR/phase1.json'))['install_cmd'])" 2>/dev/null || echo see phase1.log))"
echo "- LM Studio CLI: $(lms --version 2>/dev/null | head -1)"
echo "- claude (untouched): $(claude --version 2>/dev/null | head -1)"
echo
echo "## Models served (quant = repo id)"
python3 -c "import json;d=json.load(open('$ART_DIR/phase2.json'));print(f'- coding: {d[\"coder_repo\"]}');print(f'- docs:   {d[\"docs_repo\"]}')" 2>/dev/null || echo "(phase2.json missing)"
echo
echo "## Measured tok/s (30K prompt, 500-token completion)"
cat "$ART_DIR/phase5-tps.jsonl" 2>/dev/null || echo "(phase 5 not run)"
echo
echo "## Usable context per model (loaded, not theoretical)"
grep -iE "context|ctx" "$ART_DIR/lms-ps.txt" 2>/dev/null || cat "$ART_DIR/lms-ps.txt" 2>/dev/null || echo "(run lms ps)"
echo
echo "## Memory headroom with both models loaded"
tail -6 "$ART_DIR/memory-budget.md" 2>/dev/null || echo "(phase 2 budget missing)"
echo "Live check: $(vm_stat | awk '/free|inactive/ {s+=$3} END {printf "%.1f GB free+inactive", s*16384/1e9}' 2>/dev/null || true)"
echo
echo "## Phase 4 mapping table"
cat "$ART_DIR/phase4-mapping.md" 2>/dev/null || echo "(phase 4 not run)"
echo
echo "## Benchmark scores (from local-validation/phase6-scores.md)"
cat "$ART_DIR/phase6-scores.md" 2>/dev/null || echo "(fill in after Phase 6)"
echo
echo "## Cutover gates (independent)"
echo "- Coding gate (>= 7/10): ____  <- from phase6-scores.md"
echo "- Documentation gate (5/5 notes x 4 checks): ____  <- any fail => docs model is DRAFT-ONLY with mandatory line-by-line human review"
echo
echo "## Parallel operation"
echo "- claude (cloud, untouched): $CLAUDE_STATUS"
echo "- opencode (local): $OPENCODE_STATUS"
echo
echo "## Deviations from plan"
echo "- Plan preparation ran in a Linux cloud container with no access to this Mac; all doc-verification was done against the OpenCode v1.18.25 source tree and re-verified live by these scripts (see local-stack/README.md)."
cat "$ART_DIR/deviations.md" 2>/dev/null || true
echo "- Add any others here (e.g. 8-bit KV required, guardrail relaxation, SKIPPED-EXISTS rows in the mapping table)."
echo
echo "## Daily driver"
echo '```'
echo "opencode"
echo '```'
} > "$REPORT"

# Probation log — exact structure required by the plan.
cat > "$ART_DIR/probation-log.md" <<'EOF'
# Local Stack Probation Log

Gates and thresholds:
- coding fallback rate under 20 percent over 20 working days
- 50 consecutive clean documentation notes with any fabricated CPT code or
  unapproved abbreviation resetting the count to zero
- zero stability incidents exceeding 15 minutes
- hard stop at 60 days

| Date | Task Type | Outcome |
|------|-----------|---------|
EOF

echo "Report: $REPORT"
echo "Probation log: $ART_DIR/probation-log.md (Outcome values: clean, fallback, or incident)"
cat "$REPORT"
