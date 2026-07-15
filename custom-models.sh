#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${HOME}/.codex"
PROFILE_FILE="${CODEX_DIR}/openrouter.config.toml"
MODELS_FILE="${CODEX_DIR}/custom-models.txt"
UPDATE_SCRIPT="${CODEX_DIR}/custom-models-update.sh"
STATS_SCRIPT="${CODEX_DIR}/openrouter-stats.sh"
# ── helpers ──────────────────────────────────────────────────────────────────

is_installed() {
  [[ -f "${UPDATE_SCRIPT}" ]]
}

do_install() {
  mkdir -p "${CODEX_DIR}"

  cp "${SCRIPT_DIR}/custom-models-update.sh" "${UPDATE_SCRIPT}"
  chmod +x "${UPDATE_SCRIPT}"
  echo "Installed: ${UPDATE_SCRIPT}"

  cp "${SCRIPT_DIR}/openrouter-stats.sh" "${STATS_SCRIPT}"
  chmod +x "${STATS_SCRIPT}"
  echo "Installed: ${STATS_SCRIPT}"

  if [[ -f "${MODELS_FILE}" ]]; then
    echo "Skipped:   ${MODELS_FILE} already exists (not overwritten)."
  else
    cp "${SCRIPT_DIR}/custom-models.txt" "${MODELS_FILE}"
    echo "Created:   ${MODELS_FILE}"
  fi

  if [[ -f "${PROFILE_FILE}" ]]; then
    echo "Skipped:   ${PROFILE_FILE} already exists."
  else
    cat > "${PROFILE_FILE}" <<TOML
model_provider = "openrouter"
model_catalog_json = "~/.codex/custom-models.json"

[model_providers.openrouter]
name = "OpenRouter"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_API_KEY_CODEX"
wire_api = "responses"
TOML
    echo "Created:   ${PROFILE_FILE}"
  fi

  echo ""
  echo "Add your OpenRouter API key to your shell profile (~/.zshrc or ~/.bashrc):"
  echo "  export OPENROUTER_API_KEY_CODEX=your_key_here"
  echo "Get a key at: https://openrouter.ai/keys"
  echo ""
  echo "Generating custom-models.json..."
  "${UPDATE_SCRIPT}"
}

do_update() {
  if ! is_installed; then
    echo "Error: not installed. Run install first."
    return 1
  fi
  "${UPDATE_SCRIPT}"
}

do_stats() {
  if ! is_installed; then
    echo "Error: not installed. Run install first."
    return 1
  fi
  "${STATS_SCRIPT}"
}

do_uninstall() {
  for f in "${UPDATE_SCRIPT}" "${STATS_SCRIPT}" "${CODEX_DIR}/custom-models.json" "${PROFILE_FILE}"; do
    if [[ -f "${f}" ]]; then rm "${f}"; echo "Removed: ${f}"; else echo "Skipped: ${f} (not found)"; fi
  done

  if [[ -f "${MODELS_FILE}" ]]; then
    echo "Kept:    ${MODELS_FILE} (your model list, delete manually if needed)"
  fi

  echo ""
  echo "Uninstall complete. Codex will use its bundled model list on next run."
}

do_how_to_use() {
  echo ""
  echo "  Use OpenRouter models:"
  echo "    codex -p openrouter"
  echo ""
  echo "  Use OpenAI models (default):"
  echo "    codex"
  echo ""
  echo "  Edit your model list:"
  echo "    \${EDITOR:-nano} ${MODELS_FILE}"
  echo ""
  echo "  Update catalog after editing model list:"
  echo "    Run custom-models.sh and choose option 2"
  echo ""
  echo "  Check your OpenRouter usage and balance:"
  echo "    Run custom-models.sh and choose option 1"
  echo ""
}

# ── interactive arrow-key menu ───────────────────────────────────────────────

MENU_ITEMS=("Stats" "Update models" "Install" "Uninstall" "How to use" "Quit")
SELECTED=0
NUM_ITEMS=${#MENU_ITEMS[@]}

print_item() {
  local i=$1
  if [[ $i -eq $SELECTED ]]; then
    printf "\r\033[2K  \033[7m  %s  \033[0m\n" "${MENU_ITEMS[$i]}"
  else
    printf "\r\033[2K     %s\n" "${MENU_ITEMS[$i]}"
  fi
}

render_menu() {
  local installed
  installed=$(is_installed && echo "yes" || echo "no")

  echo ""
  echo "  codex-cli-openrouter"
  echo "  Installed: ${installed}"
  echo ""
  for i in "${!MENU_ITEMS[@]}"; do
    print_item "$i"
  done
  echo ""
  printf "  ↑↓ to move  Enter to select  q to quit"
}

# Lines below cursor after render_menu: blank + hint = 2, but cursor is on hint line (no newline)
# From hint line, item[i] is at: NUM_ITEMS - i + 1 lines up

update_selection() {
  local old=$1 new=$2
  # Move from hint line up to old selected item
  printf "\033[%dA" $(( NUM_ITEMS - old + 1 ))
  print_item "${old}"
  # Move to new selected item (print_item added a newline, so we're on old+1)
  local diff=$(( new - old - 1 ))
  if [[ $diff -gt 0 ]]; then
    printf "\033[%dB" "${diff}"
  elif [[ $diff -lt 0 ]]; then
    printf "\033[%dA" $(( -diff ))
  fi
  print_item "${new}"
  # Move back down to hint line
  printf "\033[%dB" $(( NUM_ITEMS - new ))
  printf "\r  ↑↓ to move  Enter to select  q to quit"
}

MENU_LINES=$(( NUM_ITEMS + 7 ))

clear_menu() {
  printf "\n"  # end hint line
  for _ in $(seq 1 "${MENU_LINES}"); do
    printf "\033[A\033[2K"
  done
}

run_menu() {
  # Hide cursor
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true; echo ""' EXIT

  render_menu

  while true; do
    # Read a single keypress (supports escape sequences)
    IFS= read -rsn1 key
    if [[ "${key}" == $'\x1b' ]]; then
      seq=""
      read -rsn2 -t 1 seq || true
      key="${key}${seq}"
    fi

    case "${key}" in
      $'\x1b[A'|k)  # Up
        PREV=${SELECTED}
        (( SELECTED = (SELECTED - 1 + NUM_ITEMS) % NUM_ITEMS ))
        update_selection "${PREV}" "${SELECTED}" ;;
      $'\x1b[B'|j)  # Down
        PREV=${SELECTED}
        (( SELECTED = (SELECTED + 1) % NUM_ITEMS ))
        update_selection "${PREV}" "${SELECTED}" ;;
      '')            # Enter
        break ;;
      q|Q)
        SELECTED=$(( NUM_ITEMS - 1 ))  # Quit
        break ;;
    esac
  done

  # Restore cursor and clear menu
  tput cnorm 2>/dev/null || true
  trap - EXIT
  clear_menu
}

# ── main ─────────────────────────────────────────────────────────────────────

# Fall back to numbered input if not a terminal (e.g. piped)
if [[ ! -t 0 ]]; then
  read -r CHOICE
  case "${CHOICE}" in
    1) do_stats ;;
    2) do_update ;;
    3) do_install ;;
    4) do_uninstall ;;
    5) do_how_to_use ;;
    *) exit 0 ;;
  esac
  exit 0
fi

while true; do
  SELECTED=0
  run_menu

  echo ""
  case "${SELECTED}" in
    0) do_stats ;;
    1) do_update ;;
    2) do_install ;;
    3) do_uninstall ;;
    4) do_how_to_use ;;
    5) echo "Bye."; break ;;
  esac

  echo ""
  printf "  Press any key to return to menu..."
  IFS= read -rsn1
  echo ""
done
