# Changelog

## [1.5.0] - 2026-07-15

- Mentioned the Stats command in the README intro sentence — it previously only described `custom-models.json` generation, leaving out a now-substantial feature
- Removed `uninstall.sh` — a redundant, undocumented duplicate of `install`/`run` (all three were identical one-line wrappers that just open the menu)
- Fixed stale "Run install.sh first" error message in `custom-models-update.sh` — that file was replaced by `install` back in 1.4.0
- Added Stats to the "How to use" menu screen, which predated the Stats feature
- Moved "Edit your model list" into One-time setup as step 2 (before install) — edit the repo's `custom-models.txt` so your first install already has the models you want; Daily usage now explicitly calls out that later edits go to the installed `~/.codex/custom-models.txt` instead, to head off editing the wrong copy
- Promoted "Check your OpenRouter usage and balance" from a bullet under Daily usage to its own README section — Stats has grown into a real feature, not a one-liner
- Added screenshots to README (`images/`) — the menu, Stats output, and the shortened descriptions rendering in Codex's own `/model` picker
- Fixed README: install/uninstall descriptions now mention `openrouter-stats.sh` alongside `custom-models-update.sh`
- Truncated generated model descriptions to their first sentence — OpenRouter's API already returns descriptions cut off mid-sentence at ~200-240 chars, which read as bloated and abrupt in Codex's model picker
- Reordered the menu to **Stats, Update models, Install, Uninstall, How to use, Quit** — Stats and Update models are things you'll reach for repeatedly, Install/Uninstall are one-time actions
- Fixed: `custom-models-update.sh` now pins `model = "<first slug>"` in `openrouter.config.toml` — previously the profile never set `model`, so Codex's config-layering silently fell back to the base `config.toml`'s model (e.g. `gpt-5.5`) instead of the first entry in `custom-models.txt`
- Added `openrouter-stats.sh` and a **Stats** menu item — shows OpenRouter credit balance, usage by day/week/month, this month's estimated spend per model (parsed from local Codex session logs), and the current default model's pricing/context window

## [1.4.0] - 2026-06-24

- Renamed `OPENROUTER_API_KEY` to `OPENROUTER_API_KEY_CODEX` to distinguish it when multiple OpenRouter keys are in use
- Added `install` and `run` as short wrapper scripts — alternatives to `bash custom-models.sh`
- Removed `install.sh` (replaced by `install`)
- Updated README to reflect new key name and launcher scripts

## [1.3.0] - 2026-06-11

- Rewrote README intro and solution section with sharper description

## [1.2.0] - 2026-06-11

- Strip " based on GPT-5" from `base_instructions` and `model_messages.instructions_template` in generated model entries
- Clear `availability_nux` (GPT-5.5 launch announcement) from generated model entries — not relevant for OpenRouter models

## [1.1.0] - 2026-06-11

- Added `custom-models.sh` — interactive arrow-key menu as the single entry point (install, update, uninstall, how to use)
- Added `~/.codex/openrouter.config.toml` profile — all OpenRouter config isolated to the profile, `config.toml` never modified
- Switched to Codex `-p openrouter` profile flag for per-session provider selection — fully independent terminals
- Removed bundled OpenAI models from output — all traffic routes through OpenRouter when using the profile
- `install.sh` and `uninstall.sh` now open the menu instead of running directly
- Added note: first model in `custom-models.txt` is used as the Codex default model

## [1.0.0] - 2026-06-10

Initial release.

- `custom-models-update.sh`: generates `~/.codex/custom-models.json` from OpenRouter slugs using a live Codex template
- `install.sh`: one-time setup script
- `custom-models.txt`: starter model list with slugs from Moonshot, MiniMax, DeepSeek, and Anthropic
- All files in `~/.codex/` share the `custom-models-*` naming convention for easy identification
