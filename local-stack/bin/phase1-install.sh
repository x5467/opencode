#!/usr/bin/env bash
# Phase 1: install LM Studio + OpenCode. Idempotent; never touches Claude.
set -euo pipefail
ART_DIR="./local-validation"; mkdir -p "$ART_DIR"
LOG="$ART_DIR/phase1.log"; exec > >(tee -a "$LOG") 2>&1
echo "=== Phase 1: $(date) ==="

[[ "$(uname)" == "Darwin" ]] || { echo "FATAL: must run on the Mac (Darwin), got $(uname)"; exit 1; }

# 1. Existing installs — never reinstall what is present and current.
for c in brew lms ollama opencode claude; do
  printf "%-9s: " "$c"; command -v "$c" >/dev/null 2>&1 && echo "$(command -v "$c") ($($c --version 2>/dev/null | head -1))" || echo "absent"
done
command -v brew >/dev/null || { echo "FATAL: Homebrew absent. Install from https://brew.sh then re-run."; exit 1; }

# 2. LM Studio
if [[ -d "/Applications/LM Studio.app" ]]; then
  echo "LM Studio already installed — skipping."
else
  brew install --cask lm-studio
fi

# lms CLI ships inside the app; bootstrap it onto PATH if missing.
if ! command -v lms >/dev/null 2>&1; then
  open -a "LM Studio" || true   # app must have launched once to unpack the CLI
  for p in "$HOME/.lmstudio/bin/lms" "$HOME/.cache/lm-studio/bin/lms"; do
    [[ -x "$p" ]] && { "$p" bootstrap; break; }
  done
  export PATH="$HOME/.lmstudio/bin:$PATH"
fi

# 3. OpenCode — install method verified against the OpenCode repo README
#    (recommended tap, always up to date): brew install anomalyco/tap/opencode
if command -v opencode >/dev/null 2>&1; then
  echo "OpenCode already installed: $(opencode --version) — skipping install."
  INSTALL_CMD="(pre-existing)"
else
  INSTALL_CMD="brew install anomalyco/tap/opencode"
  $INSTALL_CMD
fi
echo "OpenCode install command used: $INSTALL_CMD"

# 4. MLX backend — GUI confirmation.
cat <<'EOF'

>>> GUI STEP (only one): confirm the MLX runtime in LM Studio.
    1. Open LM Studio.
    2. Press Cmd-, (Settings) -> "Runtimes" tab.
    3. Confirm "MLX" (mlx-engine) shows Installed; click Update if offered.
    4. Confirm MLX-format models are set to use the MLX engine (default on Apple Silicon).
EOF
read -rp "Press Enter once the MLX runtime is confirmed... "

# 5. Verify both CLIs respond.
LMS_V=$(lms --version 2>&1 | head -1) || { echo "FATAL: lms not responding"; exit 1; }
OC_V=$(opencode --version 2>&1 | head -1) || { echo "FATAL: opencode not responding"; exit 1; }
echo "lms: $LMS_V"
echo "opencode: $OC_V"
printf '{"lms":"%s","opencode":"%s","install_cmd":"%s"}\n' "$LMS_V" "$OC_V" "$INSTALL_CMD" > "$ART_DIR/phase1.json"
echo "=== Phase 1 PASS ==="
