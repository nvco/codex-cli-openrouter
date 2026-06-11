#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${HOME}/.codex"
MODELS_FILE="${CODEX_DIR}/custom-models.txt"
TARGET_SCRIPT="${CODEX_DIR}/custom-models-update.sh"

# Create ~/.codex if it doesn't exist
mkdir -p "${CODEX_DIR}"

# Copy the update script
cp "${SCRIPT_DIR}/custom-models-update.sh" "${TARGET_SCRIPT}"
chmod +x "${TARGET_SCRIPT}"
echo "Installed: ${TARGET_SCRIPT}"

# Copy custom-models.txt only if one doesn't already exist
if [[ -f "${MODELS_FILE}" ]]; then
  echo "Skipped: ${MODELS_FILE} already exists (not overwritten)."
else
  cp "${SCRIPT_DIR}/custom-models.txt" "${MODELS_FILE}"
  echo "Created:  ${MODELS_FILE}"
  echo "          Edit this file to add your OpenRouter model slugs."
fi

echo ""
echo "────────────────────────────────────────────────────────────"
echo "Add the following block to ~/.codex/config.toml:"
echo "────────────────────────────────────────────────────────────"
cat <<'TOML'

model_catalog_json = "~/.codex/custom-models.json"

[model_providers.openrouter]
name = "OpenRouter"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_API_KEY"
wire_api = "responses"
TOML
echo "────────────────────────────────────────────────────────────"
echo ""
echo "Also add your API key to your shell profile (~/.zshrc or ~/.bashrc):"
echo ""
echo "  export OPENROUTER_API_KEY=your_key_here"
echo ""
echo "Get a key at: https://openrouter.ai/keys"
echo ""

# Generate the catalog immediately
echo "Generating custom-models.json..."
"${TARGET_SCRIPT}"
