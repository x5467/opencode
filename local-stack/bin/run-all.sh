#!/usr/bin/env bash
# One-command driver: runs phases 1-5 in order, stopping on the first failure.
# Phases 1, 2 and 4 pause for their built-in confirmations; answer and it continues.
# Phase 6 (interactive benchmark) and phase 7 (report) remain manual by design.
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.lmstudio/bin:$PATH"
cd "$(cd "$(dirname "$0")/.." && pwd)"
for p in phase1-install phase2-models phase3-opencode phase4-port-context phase5-bench; do
  echo; echo "########## $p ##########"; echo
  "./bin/$p.sh"
done
cat <<'EOF'

##################################################################
All automated phases PASSED.

Next (manual):
  1. open validation/scoring.md and run the Phase 6 benchmark
     (5 coding tasks + 5 clinical notes), recording scores in
     local-validation/phase6-scores.md
  2. ./bin/phase7-report.sh
##################################################################
EOF
