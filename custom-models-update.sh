#!/usr/bin/env bash
set -euo pipefail

MODELS_FILE="${HOME}/.codex/custom-models.txt"
OUTPUT_FILE="${HOME}/.codex/custom-models.json"

if [[ ! -f "${MODELS_FILE}" ]]; then
  echo "Error: ${MODELS_FILE} not found." >&2
  echo "Run install.sh first, then edit ${MODELS_FILE} with your model slugs." >&2
  exit 1
fi

if ! command -v codex &>/dev/null; then
  echo "Error: 'codex' not found in PATH. Install the Codex CLI first." >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: 'python3' not found in PATH." >&2
  exit 1
fi

TMPJSON=$(mktemp)
trap 'rm -f "${TMPJSON}"' EXIT

codex debug models --bundled > "${TMPJSON}" 2>/dev/null || {
  echo "Error: 'codex debug models --bundled' failed. Is codex installed and working?" >&2
  exit 1
}

python3 - "${OUTPUT_FILE}" "${MODELS_FILE}" "${TMPJSON}" <<'PYEOF'
import sys
import json
import copy
import urllib.request
import urllib.error

output_file = sys.argv[1]
models_file = sys.argv[2]
bundled_file = sys.argv[3]

# Read slugs (skip blanks and comments)
slugs = []
with open(models_file) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        slugs.append(line)

if not slugs:
    print(f"Error: No model slugs found in {models_file}.", file=sys.stderr)
    sys.exit(1)

# Parse bundled JSON from temp file
with open(bundled_file) as f:
    bundled_raw = f.read()
try:
    bundled = json.loads(bundled_raw)
except json.JSONDecodeError as e:
    print(f"Error: could not parse 'codex debug models --bundled' output: {e}", file=sys.stderr)
    sys.exit(1)

# Extract the first model entry as a template
models_list = None
if isinstance(bundled, dict):
    for key in ("models", "data", "items"):
        if key in bundled and isinstance(bundled[key], list) and bundled[key]:
            models_list = bundled[key]
            break
    if models_list is None:
        for v in bundled.values():
            if isinstance(v, list) and v:
                models_list = v
                break
elif isinstance(bundled, list) and bundled:
    models_list = bundled

if not models_list:
    print("Error: could not find a model list in 'codex debug models --bundled' output.", file=sys.stderr)
    sys.exit(1)

template = models_list[0]

# Fetch OpenRouter catalog
try:
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/models",
        headers={"User-Agent": "codex-cli-openrouter/1.0"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        or_data = json.loads(resp.read().decode())
except urllib.error.URLError as e:
    print(f"Warning: could not fetch OpenRouter catalog: {e}", file=sys.stderr)
    or_data = {"data": []}

or_catalog = {m.get("id", ""): m for m in or_data.get("data", []) if m.get("id")}

# Build custom model entries
custom_entries = []
warnings = 0

for slug in slugs:
    entry = copy.deepcopy(template)

    entry["availability_nux"] = None

    if "base_instructions" in entry:
        entry["base_instructions"] = entry["base_instructions"].replace(" based on GPT-5", "")
    try:
        tmpl = entry["model_messages"]["instructions_template"]
        if tmpl:
            entry["model_messages"]["instructions_template"] = tmpl.replace(" based on GPT-5", "")
    except (KeyError, TypeError):
        pass

    # Set the model id using whatever key the template uses
    id_key = next((k for k in ("id", "model", "name", "slug") if k in entry), None)
    if id_key:
        entry[id_key] = slug
    else:
        entry["id"] = slug

    or_meta = or_catalog.get(slug)
    if or_meta is None:
        print(f"Warning: slug '{slug}' not found in OpenRouter catalog — using template defaults.", file=sys.stderr)
        warnings += 1
    else:
        display_name = or_meta.get("name", slug)
        description  = or_meta.get("description", entry.get("description", ""))
        ctx          = or_meta.get("context_length") or or_meta.get("context_window")
        max_ctx      = (or_meta.get("top_provider") or {}).get("max_completion_tokens") or ctx

        # Overlay display name
        name_key = next((k for k in ("display_name", "displayName") if k in entry), None)
        if name_key:
            entry[name_key] = display_name
        else:
            entry["display_name"] = display_name

        if "description" in entry:
            entry["description"] = description

        if ctx is not None:
            ctx_key = next((k for k in ("context_window", "contextWindow", "context_length") if k in entry), None)
            if ctx_key:
                entry[ctx_key] = ctx

        if max_ctx is not None:
            max_key = next((k for k in ("max_context_window", "maxContextWindow", "max_context_length") if k in entry), None)
            if max_key:
                entry[max_key] = max_ctx

    custom_entries.append(entry)

with open(output_file, "w") as f:
    json.dump({"models": custom_entries}, f, indent=2)

warn_str = f", {warnings} warning(s)" if warnings else ""
print(f"Wrote {len(custom_entries)} model(s) to {output_file}{warn_str}.")
PYEOF
