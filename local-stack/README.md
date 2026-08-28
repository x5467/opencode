# Local LLM Stack — Runbook

Target machine: MacBook Pro 16" M5 Max, 64 GB unified memory, macOS.
Everything below runs **on the Mac**, not in CI. Scripts are phased; each
phase verifies itself and refuses to continue on failure (diagnose, retry
once, then stop — per plan).

> **DEVIATION FLAG (mandatory disclosure):** this plan was *prepared* in a
> Linux x86_64 cloud container (Claude Code remote session) that has no
> access to the target Mac. Nothing could be installed or measured on the
> Mac from that session. Instead, every fact that the plan says must be
> verified against current OpenCode documentation was verified against the
> **OpenCode source tree at v1.18.25** (this very repository, checked out at
> `sync release versions for v1.18.25`) and its shipped docs
> (`packages/web/src/content/docs/{providers,config,rules,skills,share}.mdx`),
> and both model IDs were confirmed to exist on Hugging Face. The scripts
> re-verify everything at run time on the Mac (`opencode --version`, live
> `/v1/models`, actual model `config.json` for KV math), so a newer
> installed version is re-checked locally, not trusted from memory.

## Architecture (as verified)

- **Inference server:** LM Studio, MLX engine (auto-selected for MLX-format
  models). Fallback: Ollama ≥ 0.19.
- **Coding model:** Qwen3-Coder-30B-A3B-Instruct, MLX 4-bit.
  Preference order (first available wins, script tries in order):
  1. `unsloth/Qwen3-Coder-30B-A3B-Instruct-UD-MLX-4bit` (unsloth dynamic, if published)
  2. `lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit` (confirmed to exist)
  3. `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` (confirmed to exist)
- **Documentation model:** Qwen3.6-35B-A3B, MLX 4-bit.
  1. `unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit` (confirmed to exist — unsloth dynamic)
  2. `lmstudio-community/Qwen3.6-35B-A3B-MLX-4bit` (confirmed to exist)
  3. `mlx-community/Qwen3.6-35B-A3B-4bit` (confirmed to exist)
- **Challenger watch:** re-run `bin/phase2-models.sh --check-challenger`
  weekly; it searches the catalog for Qwen3.8-27B MLX/unsloth quants and
  tells you to re-run Phase 5/6 if found. Setup does not block on it.
- **Agent client:** OpenCode (`brew install anomalyco/tap/opencode` — the
  README-recommended tap, always current) against
  `http://127.0.0.1:1234/v1`.

## Execution order

```bash
cd local-stack
./bin/phase1-install.sh      # installs; pauses for the one GUI step
./bin/phase2-models.sh       # downloads, memory budget + 12GB gate, server, tool-call test
./bin/phase3-opencode.sh     # writes verified opencode.json, locks out cloud, round-trip tests
./bin/phase4-port-context.sh # copy-only port of CLAUDE.md + skills, byte-audit table
./bin/phase5-bench.sh        # 30K-prompt / 500-token tok/s gate (≥20 tok/s per model)
# Phase 6 is interactive — see validation/scoring.md
./bin/phase7-report.sh       # final report + probation log
```

All machine-readable phase artifacts land in `./local-validation/` (created
at repo root of wherever you run the scripts) and `phase7-report.sh`
assembles them.

## The one GUI step (Phase 1)

LM Studio's MLX runtime ships with the app but confirm it is present and
current:

1. Open **LM Studio**.
2. Press **⌘ ,** (Settings) → **Runtimes** tab.
3. In the runtime list confirm **MLX** (`mlx-engine`) shows *Installed* —
   click **Update** if an update is offered.
4. Under *Model format preferences* confirm MLX models are set to use the
   MLX engine (this is the default on Apple Silicon).

`phase1-install.sh` prints this and pauses until you confirm.

## Memory budget (pre-computed; Phase 2 recomputes from the actual downloaded weights)

KV bytes/token = 2 (K+V) × layers × kv_heads × head_dim × 2 bytes (fp16).
For Qwen3-Coder-30B-A3B (48 layers, 4 KV heads GQA, head_dim 128):
96 KiB/token → 6.0 GiB @ 64K, 12.0 GiB @ 128K. The 35B-A3B doc model is
estimated at the same order (Phase 2 reads its real `config.json`).

| Item | Est. GB |
|---|---|
| Coder weights (MLX 4-bit) | ~17.2 |
| Docs weights (MLX 4-bit) | ~19.7 |
| KV coder @ 64K (fp16) | ~6.0 |
| KV docs @ 64K (fp16, est.) | ~7.0 |
| LM Studio + Metal runtime overhead | ~2.5 |
| **Total @ 64K each** | **~52.4** |
| **Headroom vs 64 GB** | **~11.6 → borderline vs 12 GB rule** |
| Total @ 128K each | ~65+ → **REJECTED by hard rule** |

Consequences, enforced by `phase2-models.sh`:
- Context is configured at **65,536 per model** (the plan's minimum).
  128K per model **fails the 12 GB rule** and is rejected.
- Because 64K/fp16 is borderline, the script enables **8-bit KV cache
  quantization** in LM Studio's per-model load options, halving KV to
  ~6.5 GB combined → headroom ~18 GB, comfortably compliant. If 8-bit KV
  is unavailable in the installed LM Studio build, the script falls back
  to fp16 KV and only passes if measured free memory ≥ 12 GB with both
  models loaded (it checks `vm_stat`, not estimates).
- macOS caps GPU-wired memory below 64 GB (default recommended working
  set ≈ 48 GB on a 64 GB machine). Two models ≈ 50 GB wired may trip LM
  Studio's guardrails. The script detects the failure and prints the fix:
  set LM Studio guardrails to "Relaxed" (Settings → Hardware) and/or
  `sudo sysctl iogpu.wired_limit_mb=57344` (resets on reboot; never made
  permanent by these scripts).

## Cloud lockout (Phase 3)

Verified against v1.18.25 source and shipped docs:
- Global config lives at `~/.config/opencode/opencode.json`.
- Custom provider uses `npm: "@ai-sdk/openai-compatible"` +
  `options.baseURL` (`packages/web/src/content/docs/providers.mdx`, "LM Studio").
- `disabled_providers` is honored in `packages/opencode/src/provider/provider.ts:1441`
  — the config disables every major cloud provider by ID so a set
  `ANTHROPIC_API_KEY` (which stays untouched, per constraints) can never
  activate the Anthropic provider inside OpenCode, and a fat-fingered
  model switch has nothing cloud-side to land on.
- `"share": "disabled"` turns off the session-sharing service.
- Verification: `opencode providers` must list **only** the `lmstudio`
  provider as enabled.

## Parallel operation (constraint, verified in Phase 7)

Nothing in these scripts touches `~/.claude`, `ANTHROPIC_*`, any
`CLAUDE.md`, or any skill file. Phase 4 is copy-only; originals are the
rollback path. Phase 7 launches `claude` (expects a normal cloud session)
and `opencode` (expects the local session) and reports each independently.

## Daily driver command

```bash
opencode
```

(from any project directory — the global config pins
`lmstudio/<coder-model-id>` as default; switch to the docs model in-session
with `/models`.)
