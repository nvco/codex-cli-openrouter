# Changelog

## [1.1.0] - 2026-06-11

- Added `custom-models.sh` — interactive arrow-key menu as the single entry point (install, update, uninstall, how to use)
- Added `~/.codex/openrouter.config.toml` profile — all OpenRouter config isolated to the profile, `config.toml` never modified
- Switched to Codex `-p openrouter` profile flag for per-session provider selection — fully independent terminals
- Removed bundled OpenAI models from output — all traffic routes through OpenRouter when using the profile
- `install.sh` and `uninstall.sh` now open the menu instead of running directly
- Added tip: `profile = "openrouter"` in `config.toml` makes OpenRouter the permanent default
- Added note: first model in `custom-models.txt` is used as the Codex default model

## [1.0.0] - 2026-06-10

Initial release.

- `custom-models-update.sh`: generates `~/.codex/custom-models.json` from OpenRouter slugs using a live Codex template
- `install.sh`: one-time setup script
- `custom-models.txt`: starter model list with slugs from Moonshot, MiniMax, DeepSeek, and Anthropic
- All files in `~/.codex/` share the `custom-models-*` naming convention for easy identification
