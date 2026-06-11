# Changelog

## [1.0.0] - 2026-06-10

Initial release.

- `custom-models-update.sh`: generates `~/.codex/custom-models.json` by combining Codex's bundled models with custom OpenRouter entries, using the bundled catalog as a live schema template
- `install.sh`: one-time setup — copies scripts and model list to `~/.codex/`, generates `custom-models.json` immediately
- `custom-models.txt`: starter model list with slugs from Moonshot, MiniMax, DeepSeek, and Anthropic
- All files in `~/.codex/` share the `custom-models-*` naming convention for easy identification
