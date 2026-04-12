#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd -P)
SUPPORT_DIR="$HOME/.testing"
API_KEY_FILE="$SUPPORT_DIR/openrouter.sk"
E2E_SUPPORT_DIR="/tmp/flowdown-online-e2e"
ENABLE_MARKER="$E2E_SUPPORT_DIR/flowdown_e2e_enabled"
RUNTIME_API_KEY_FILE="$E2E_SUPPORT_DIR/openrouter.sk"

if [[ -f "$HOME/.zprofile" ]]; then
    source "$HOME/.zprofile"
fi

if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc"
fi

mkdir -p "$SUPPORT_DIR"
mkdir -p "$E2E_SUPPORT_DIR"

if [[ -z "${OPENROUTER_API_KEY:-}" && -f "$API_KEY_FILE" ]]; then
    OPENROUTER_API_KEY=$(<"$API_KEY_FILE")
fi

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    echo "[-] OPENROUTER_API_KEY is not configured" >&2
    exit 1
fi

printf '%s\n' "$OPENROUTER_API_KEY" > "$API_KEY_FILE"
printf '%s\n' "$OPENROUTER_API_KEY" > "$RUNTIME_API_KEY_FILE"
chmod 600 "$API_KEY_FILE" "$RUNTIME_API_KEY_FILE"
touch "$ENABLE_MARKER"

cleanup() {
    rm -f "$ENABLE_MARKER" "$RUNTIME_API_KEY_FILE"
}

trap cleanup EXIT

echo "[+] running online e2e"

cd "$REPO_ROOT"

xcodebuild -downloadComponent MetalToolchain > /dev/null
DESTINATION=$(bash Resources/DevKit/scripts/get_first_ios_simulator.sh)

set -o pipefail
xcodebuild \
  -workspace FlowDown.xcworkspace \
  -scheme FlowDown \
  -configuration Debug \
  -destination "$DESTINATION" \
  test \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  | xcbeautify -qq
