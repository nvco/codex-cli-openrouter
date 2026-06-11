# codex-cli-openrouter

Use any [OpenRouter](https://openrouter.ai) model with the [Codex CLI](https://github.com/openai/codex) without fighting schema errors.

---

## The problem

Using Codex CLI with non-OpenAI models via OpenRouter is extremely common. Developers want access to the full OpenRouter catalog (Kimi, Gemini, Claude, DeepSeek, and hundreds more) without being locked into OpenAI models. OpenRouter even has an [official Codex CLI integration page](https://openrouter.ai/docs/community/codex).

The catch: Codex's `model_catalog_json` has a strict JSON schema with ~20 required fields, none of which are documented. Every attempt to write a custom catalog by hand results in a `missing field` error, one field at a time. This is a well-travelled path with a poorly documented sharp edge.

## The solution

This repo generates a valid `custom-models.json` automatically by:

1. Running `codex debug models --bundled` to extract a real, valid model entry from the binary as a template (so the schema is always correct, even after Codex updates)
2. Fetching live metadata for your chosen model slugs from the [OpenRouter public API](https://openrouter.ai/api/v1/models) (no auth required)
3. Overlaying the OpenRouter metadata (slug, display name, description, context window) onto the template
4. Writing the result to `~/.codex/custom-models.json`

No hardcoded schema. No npm. No pip. Just `bash` and `python3`.

---

## Prerequisites

- [`codex` CLI](https://github.com/openai/codex) installed and in your PATH
- `python3` (standard on macOS and Linux)
- An [OpenRouter API key](https://openrouter.ai/keys)

---

## One-time setup

**1. Clone this repo**

```bash
git clone https://github.com/nvco/codex-cli-openrouter.git ~/projects/codex-cli-openrouter
cd ~/projects/codex-cli-openrouter
```

**2. Run the installer**

```bash
bash install.sh
```

This will:
- Copy `custom-models-update.sh` to `~/.codex/`
- Copy `custom-models.txt` to `~/.codex/custom-models.txt` (if one doesn't exist yet)
- Print the `config.toml` block you need to add (see next step)
- Run `custom-models-update.sh` to generate `custom-models.json` immediately

**3. Add the config block to `~/.codex/config.toml`**

Add this to `~/.codex/config.toml`:

```toml
model_catalog_json = "~/.codex/custom-models.json"

[model_providers.openrouter]
name = "OpenRouter"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_API_KEY"
wire_api = "responses"
# ...
```

---

## Daily usage

**1. Edit your model list**

```bash
nano ~/.codex/custom-models.txt
```

One OpenRouter slug per line. Blank lines and `#` comments are ignored. Find slugs at [openrouter.ai/models](https://openrouter.ai/models).

```
# Moonshot AI
moonshotai/kimi-k2.6

# MiniMax
minimax/minimax-m3
# minimax/minimax-m2.7

# DeepSeek
deepseek/deepseek-v4-pro
deepseek/deepseek-v4-flash

# Anthropic
# anthropic/claude-sonnet-4.6
```

**2. Regenerate the catalog**

```bash
~/.codex/custom-models-update.sh
```

Example output:
```
Wrote 12 model(s) to /Users/you/.codex/custom-models.json (8 bundled + 4 custom).
```

**3. Verify**

```bash
codex debug models | python3 -m json.tool | grep display_name
```

---

## Note: bundled models are included

The script includes all of Codex's built-in models in the output, followed by your custom entries. You get the full OpenAI catalog plus your OpenRouter models in one file — no need to add OpenAI models to `custom-models.txt` manually.

---

## Troubleshooting

**"slug not found in OpenRouter catalog"**
The slug wasn't returned by the OpenRouter API. Double-check the exact slug at [openrouter.ai/models](https://openrouter.ai/models) by copying it from the model's URL or the API id field. The script will still write an entry using template defaults, so it won't fail.

**`codex debug models --bundled` fails**
Verify `codex` is in your PATH: `which codex`. If the command is missing, reinstall the Codex CLI.

**Network error fetching OpenRouter API**
Check your internet connection and try again. The script will print a warning and fall back to template defaults for all models rather than failing.

**Models don't appear in Codex after running the script**
Make sure the `model_catalog_json` line is in `~/.codex/config.toml` and the path is correct. Run `codex debug models` (without `--bundled`) to see what Codex is actually loading.

---

## Uninstall

Remove the files and the config block:

```bash
rm ~/.codex/custom-models-update.sh
rm ~/.codex/custom-models.txt
rm ~/.codex/custom-models.json
```

Then remove the block you added to `~/.codex/config.toml`:

```toml
model_catalog_json = "~/.codex/custom-models.json"

[model_providers.openrouter]
name = "OpenRouter"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_API_KEY"
wire_api = "responses"
```

Codex will fall back to its bundled model list.
