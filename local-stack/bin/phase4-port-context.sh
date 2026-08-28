#!/usr/bin/env bash
# Phase 4: COPY-ONLY context port. CLAUDE.md -> AGENTS.md (same dir);
# ~/.claude/skills -> ~/.config/opencode/skills. Originals are never touched.
#
# Verified against OpenCode v1.18.25 docs:
# - AGENTS.md is read natively (project root + ~/.config/opencode/AGENTS.md); if no
#   AGENTS.md exists OpenCode already falls back to CLAUDE.md — the copy makes the
#   local stack independent of the Claude files so they stay a pure rollback path.
# - Skills: ~/.config/opencode/skills/<name>/SKILL.md; frontmatter needs only
#   name+description (Claude skills already have both; unknown fields are IGNORED,
#   so content transfers byte-for-byte verbatim — zero words change).
set -euo pipefail
ART_DIR="./local-validation"; mkdir -p "$ART_DIR"
LOG="$ART_DIR/phase4.log"; exec > >(tee -a "$LOG") 2>&1
echo "=== Phase 4: $(date) ==="

# 1. Discovery — list EVERYTHING before changing anything.
echo "--- Discovery: CLAUDE.md files ---"
CLAUDE_FILES=()
[[ -f "$HOME/.claude/CLAUDE.md" ]] && CLAUDE_FILES+=("$HOME/.claude/CLAUDE.md")
while IFS= read -r f; do CLAUDE_FILES+=("$f"); done < <(
  find "$HOME" -maxdepth 6 -name CLAUDE.md \
    -not -path "*/Library/*" -not -path "*/node_modules/*" -not -path "*/.Trash/*" \
    -not -path "$HOME/.claude/*" 2>/dev/null | sort)
printf '%s\n' "${CLAUDE_FILES[@]:-none found}"
echo "--- Discovery: skill files ---"
SKILL_FILES=()
while IFS= read -r f; do SKILL_FILES+=("$f"); done < <(
  find "$HOME/.claude/skills" -name SKILL.md -maxdepth 3 2>/dev/null | sort)
printf '%s\n' "${SKILL_FILES[@]:-none found}"
read -rp "Review the lists above. Enter to proceed with COPY-only port (Ctrl-C aborts)... "

TABLE="$ART_DIR/phase4-mapping.md"
{ echo "| Source | Destination | Bytes in | Bytes out | Match |"; echo "|---|---|---|---|---|"; } > "$TABLE"
FAIL=0
row() { # src dst
  local bi bo ok
  bi=$(wc -c < "$1" | tr -d ' '); bo=$(wc -c < "$2" | tr -d ' ')
  ok=$([[ "$bi" == "$bo" ]] && echo PASS || echo FAIL); [[ "$ok" == FAIL ]] && FAIL=1
  echo "| $1 | $2 | $bi | $bo | $ok |" >> "$TABLE"
}

# 2. CLAUDE.md -> AGENTS.md, same locations. Global copy goes to OpenCode's global path.
for src in "${CLAUDE_FILES[@]:-}"; do
  [[ -z "$src" ]] && continue
  if [[ "$src" == "$HOME/.claude/CLAUDE.md" ]]; then
    dst="$HOME/.config/opencode/AGENTS.md"; mkdir -p "$(dirname "$dst")"
  else
    dst="$(dirname "$src")/AGENTS.md"
  fi
  if [[ -e "$dst" ]]; then
    echo "SKIP (exists, not clobbering): $dst"; echo "| $src | $dst | - | - | SKIPPED-EXISTS |" >> "$TABLE"; continue
  fi
  cp -p "$src" "$dst"; row "$src" "$dst"
done

# 3. Skills, verbatim: whole skill dirs copied to OpenCode's global skills path.
DEST_SKILLS="$HOME/.config/opencode/skills"; mkdir -p "$DEST_SKILLS"
for src in "${SKILL_FILES[@]:-}"; do
  [[ -z "$src" ]] && continue
  sdir="$(dirname "$src")"; name="$(basename "$sdir")"
  if [[ -e "$DEST_SKILLS/$name" ]]; then
    echo "SKIP (exists): $DEST_SKILLS/$name"; echo "| $sdir/ | $DEST_SKILLS/$name/ | - | - | SKIPPED-EXISTS |" >> "$TABLE"; continue
  fi
  cp -Rp "$sdir" "$DEST_SKILLS/$name"
  # byte-audit every file in the skill dir, not just SKILL.md
  while IFS= read -r f; do
    rel="${f#"$sdir"/}"; row "$f" "$DEST_SKILLS/$name/$rel"
  done < <(find "$sdir" -type f | sort)
done

# 4. Mapping table. Any mismatch is a hard failure needing line-by-line explanation.
cat "$TABLE"
[[ "$FAIL" == 1 ]] && { echo "FATAL: byte-count mismatch — diff each FAIL row line by line before proceeding."; exit 1; }

# Note: OpenCode ALSO reads ~/.claude/skills natively; if a skill lists twice in a
# session, content is identical (verbatim copies) — benign, but note it in the report.

# 5. Recitation check: rules that exist only in the ported files.
CODER_ID=$(python3 -c "import json;print(json.load(open('$ART_DIR/phase3.json'))['docs'])" 2>/dev/null) || CODER_ID=""
echo "--- Recitation check (docs model) ---"
opencode run ${CODER_ID:+-m "lmstudio/$CODER_ID"} \
  "Load your clinical documentation skills. Then answer: what documentation rules do you operate under for PTA notes? Quote the goal character cap, name three approved abbreviations, and name the two EMR formats you support." \
  | tee "$ART_DIR/phase4-recitation.txt"
echo "MANUAL GATE: confirm the recitation above quotes rules that exist ONLY in the ported files (e.g. the 200-char goal cap, your CPT tables). If it recites nothing specific, the port failed."
echo "=== Phase 4 complete (pending your recitation confirmation) ==="
