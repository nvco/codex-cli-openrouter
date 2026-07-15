#!/usr/bin/env bash
set -euo pipefail

CODEX_DIR="${HOME}/.codex"
MODELS_FILE="${CODEX_DIR}/custom-models.txt"
SESSIONS_DIR="${CODEX_DIR}/sessions"

if ! command -v python3 &>/dev/null; then
  echo "Error: 'python3' not found in PATH." >&2
  exit 1
fi

python3 - "${MODELS_FILE}" "${SESSIONS_DIR}" "${OPENROUTER_API_KEY_CODEX:-}" <<'PYEOF'
import sys
import os
import json
import glob
import urllib.request
import urllib.error
from datetime import datetime, timedelta

models_file, sessions_dir, api_key = sys.argv[1], sys.argv[2], sys.argv[3]


def fetch_json(url, auth=False):
    headers = {"User-Agent": "codex-cli-openrouter/1.0"}
    if auth:
        headers["Authorization"] = f"Bearer {api_key}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def fmt_usd(x):
    return f"${x:,.2f}"


def fmt_tokens(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}K"
    return str(n)


print("-" * 60)
print()
print("OpenRouter Stats")
print()

# ── Account ──────────────────────────────────────────────────────────────
print("Account")
if not api_key:
    print("  OPENROUTER_API_KEY_CODEX not set — skipping balance/usage.")
else:
    try:
        credits = fetch_json("https://openrouter.ai/api/v1/credits", auth=True)["data"]
        total_credits = credits.get("total_credits")
        total_usage = credits.get("total_usage", 0)
        if total_credits is not None:
            remaining = total_credits - total_usage
            print(f"  Balance remaining   {fmt_usd(remaining)}")
        else:
            print(f"  Total usage         {fmt_usd(total_usage)}  (pay-as-you-go, no credit cap)")
    except (urllib.error.URLError, KeyError, TypeError, ValueError) as e:
        print(f"  Warning: could not fetch credits: {e}")

    try:
        key_info = fetch_json("https://openrouter.ai/api/v1/key", auth=True)["data"]
        print(f"  Usage today          {fmt_usd(key_info.get('usage_daily', 0))}")
        print(f"  Usage this week      {fmt_usd(key_info.get('usage_weekly', 0))}")
        print(f"  Usage this month     {fmt_usd(key_info.get('usage_monthly', 0))}")
    except (urllib.error.URLError, KeyError, TypeError, ValueError) as e:
        print(f"  Warning: could not fetch key usage: {e}")
print()

# ── OpenRouter model catalog (pricing + context, public, no auth) ─────────
catalog = {}
catalog_available = True
try:
    or_data = fetch_json("https://openrouter.ai/api/v1/models")
    catalog = {m["id"]: m for m in or_data.get("data", []) if m.get("id")}
except (urllib.error.URLError, KeyError, TypeError, ValueError):
    catalog_available = False


def model_cost(slug, input_tokens, cached_tokens, output_tokens):
    pricing = catalog.get(slug, {}).get("pricing", {})
    prompt_price = float(pricing.get("prompt", 0) or 0)
    completion_price = float(pricing.get("completion", 0) or 0)
    cache_price = float(pricing.get("input_cache_read", prompt_price) or prompt_price)
    uncached = max(input_tokens - cached_tokens, 0)
    return uncached * prompt_price + cached_tokens * cache_price + output_tokens * completion_price


# ── Local usage by model (parsed from Codex session logs) ────────────────
def collect_openrouter_usage(session_files):
    per_model = {}
    session_count = 0

    for path in session_files:
        provider = None
        model = None
        last_usage = None
        try:
            with open(path, encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        d = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    t = d.get("type")
                    payload = d.get("payload") or {}
                    if t == "session_meta":
                        provider = payload.get("model_provider")
                    elif t == "turn_context":
                        model = payload.get("model") or model
                    elif t == "event_msg" and payload.get("type") == "token_count":
                        usage = (payload.get("info") or {}).get("total_token_usage")
                        if usage:
                            last_usage = usage
        except OSError:
            continue

        if provider == "openrouter" and model and last_usage:
            session_count += 1
            pm = per_model.setdefault(model, {"sessions": 0, "input": 0, "cached": 0, "output": 0})
            pm["sessions"] += 1
            pm["input"] += last_usage.get("input_tokens", 0)
            pm["cached"] += last_usage.get("cached_input_tokens", 0)
            pm["output"] += last_usage.get("output_tokens", 0)

    return per_model, session_count


def print_usage_section(title, empty_label, session_files):
    print(f"Local usage ({title}, this machine)")

    per_model, session_count = collect_openrouter_usage(session_files)

    if not per_model:
        print(f"  No local OpenRouter sessions found {empty_label}.")
    else:
        costs = {
            model: model_cost(model, v["input"], v["cached"], v["output"])
            for model, v in per_model.items()
        }
        total_cost = sum(costs.values())

        print(f"  Sessions             {session_count}")
        if catalog_available:
            print(f"  Total est. spend     {fmt_usd(total_cost)}")
        else:
            print("  Total est. spend     unavailable (could not reach OpenRouter catalog)")
        print()

        ranked = sorted(per_model.items(), key=lambda kv: -costs.get(kv[0], 0))
        MAX_ROWS = 8
        for model, v in ranked[:MAX_ROWS]:
            sessions_label = f"{v['sessions']} session" + ("s" if v["sessions"] != 1 else "")
            tok_label = f"{fmt_tokens(v['input'])} in / {fmt_tokens(v['output'])} out"
            cost_label = fmt_usd(costs[model]) if catalog_available else "?"
            print(f"    {model:<32s} {sessions_label:<12s} {tok_label:<20s} {cost_label}")
        if len(ranked) > MAX_ROWS:
            print(f"    +{len(ranked) - MAX_ROWS} more not shown")
    print()


now = datetime.now()

week_start = now - timedelta(days=now.weekday())
week_days = [week_start + timedelta(days=i) for i in range((now - week_start).days + 1)]
week_dirs = [os.path.join(sessions_dir, f"{d.year:04d}", f"{d.month:02d}", f"{d.day:02d}") for d in week_days]
week_files = [f for d in week_dirs for f in glob.glob(os.path.join(d, "*.jsonl"))]
print_usage_section("this week", "this week", week_files)

month_dir = os.path.join(sessions_dir, f"{now.year:04d}", f"{now.month:02d}")
month_files = glob.glob(os.path.join(month_dir, "**", "*.jsonl"), recursive=True)
print_usage_section(now.strftime("%B %Y"), "this month", month_files)

year_dir = os.path.join(sessions_dir, f"{now.year:04d}")
year_files = glob.glob(os.path.join(year_dir, "**", "*.jsonl"), recursive=True)
print_usage_section(str(now.year), "this year", year_files)

# ── Current default model ──────────────────────────────────────────────
print("Current default model")

default_slug = None
try:
    with open(models_file, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                default_slug = line
                break
except OSError:
    pass

if not default_slug:
    print("  No default model set (edit ~/.codex/custom-models.txt).")
else:
    meta = catalog.get(default_slug)
    if not meta:
        print(f"  {default_slug}   (not found in OpenRouter catalog)")
    else:
        ctx = meta.get("context_length")
        pricing = meta.get("pricing", {})
        prompt_price = float(pricing.get("prompt", 0) or 0) * 1_000_000
        completion_price = float(pricing.get("completion", 0) or 0) * 1_000_000
        ctx_label = f"{fmt_tokens(ctx)} context" if ctx else "context unknown"
        print(f"  {default_slug}   {ctx_label}   {fmt_usd(prompt_price)}/1M in   {fmt_usd(completion_price)}/1M out")
PYEOF
