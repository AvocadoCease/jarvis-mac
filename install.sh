#!/bin/bash
# One-time setup on the Mac (Apple Silicon, macOS 13+). Safe to run again.
#
# Before running: copy config.example.json to config.json and fill it in (see README).
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
AGENTS="$HOME/Library/LaunchAgents"
DOMAIN="gui/$(id -u)"

[ -f "$ROOT/config.json" ] || { cp "$ROOT/config.example.json" "$ROOT/config.json";
  echo "Created config.json from the example. Fill it in, then run ./install.sh again."; exit 1; }
command -v brew >/dev/null || { echo "Needs Homebrew: https://brew.sh"; exit 1; }
command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] || {
  echo "Needs Claude Code, logged in: https://claude.com/claude-code"; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Needs the Xcode command line tools: run  xcode-select --install"; exit 1; }

echo "== Tools (ffmpeg, whisper.cpp)"
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
brew list whisper-cpp >/dev/null 2>&1 || brew install whisper-cpp
mkdir -p "$HOME/Library/Logs/jarvis-mac" "$HOME/.config/jarvis-mac" "$AGENTS"

PYTHON="$(command -v python3)"
WHISPER="$(command -v whisper-server || echo /opt/homebrew/bin/whisper-server)"
PROMPT="$("$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1])).get("whisper_prompt","JARVIS."))' "$ROOT/config.json" | sed 's/[#&]//g')"

render() {  # launchd/<name>.plist -> ~/Library/LaunchAgents, then (re)load it
  local label="com.jarvis-mac.$1" dst="$AGENTS/com.jarvis-mac.$1.plist"
  sed -e "s#__ROOT__#$ROOT#g" -e "s#__HOME__#$HOME#g" -e "s#__PYTHON__#$PYTHON#g" \
      -e "s#__WHISPER__#$WHISPER#g" -e "s#__PROMPT__#$PROMPT#g" "$ROOT/launchd/$1.plist" > "$dst"
  if [ "$1" != app ]; then
    launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$dst"
    echo "   started $label"
  fi
}

echo "== Whisper model (local speech-to-text, about 550 MB)"
MODEL="$ROOT/app/models/ggml-large-v3-turbo-q5_0.bin"
if [ ! -f "$MODEL" ]; then
  mkdir -p "$(dirname "$MODEL")"
  curl -L --fail -o "$MODEL" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin
fi
render whisper

echo "== JARVIS server (127.0.0.1:8787)"
render server

echo "== Jarvis.app"
[ -f "$HOME/.config/jarvis-mac/replacements.json" ] || cp "$ROOT/app/replacements.example.json" "$HOME/.config/jarvis-mac/replacements.json"
"$ROOT/app/build.sh"
render app   # opens Jarvis.app at login

echo
echo "Done. Grant Jarvis.app Microphone, Accessibility and Input Monitoring when macOS asks."
echo "Then hold fn and talk to dictate, or hold Right Option to ask JARVIS. Check it:  ./jarvis status"
