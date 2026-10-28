# Setting up JARVIS on someone's Mac: instructions for the AI agent

You are helping a person set up this project on their own Mac. Read this file and `README.md`
before changing anything.

## What this project is

- **`app/`** is Jarvis.app, a menu bar app in Swift:
  - Hold fn to dictate into any app; the text is pasted where the cursor is.
  - Hold Right Option to ask JARVIS; the answer is spoken, with the reactor animation on screen.
  - Speech-to-text is whisper.cpp's `whisper-server` on 127.0.0.1:8178.
- **`server/serve.py`** is a small HTTP server on **127.0.0.1:8787**, local only. The app sends
  questions there and gets back the answer and its voice.
- **`server/brain.py`** keeps one `claude -p` (Claude Code, headless) running on the person's own
  login.
  - It answers with their claude.ai connectors (Calendar, Gmail, Drive, Slack, Jira) and can use
    the Mac: Bash, files and the web.
  - Looking runs straight away. Anything that changes something waits for a spoken "go ahead".
- **Three background services** are set up by `install.sh` as LaunchAgents:
  - `com.jarvis-mac.server`
  - `com.jarvis-mac.whisper`
  - `com.jarvis-mac.app`, which opens the app at login.

## Step 1: check what they have (don't assume)

1. **An Apple Silicon Mac** on macOS 13 or later. Check with `uname -m`, which should print `arm64`,
   and `sw_vers`.
2. **Homebrew** (`brew`) and the Xcode command line tools (`xcode-select -p`).
3. **Claude Code**, installed and logged in: `claude` works in a terminal.
   - If their connectors are on a non-default Claude config dir, set `claude_config_dir` in
     `config.json`.
   - **Never ask them for OAuth codes, tokens or passwords.** They connect connectors themselves in
     claude.ai → Settings → Connectors.
4. **Nothing else on ports 8787 or 8178:** `lsof -i :8787 -i :8178`.

## Step 2: install

```bash
cp config.example.json config.json   # fill in WITH the person: user_name, place, timezone, whisper_prompt
./install.sh
./jarvis status                      # {"ok": true, "claude_ready": true, ...}
```

- `timezone` is an IANA name such as `Africa/Johannesburg` or `Europe/London`.
- `whisper_prompt` is a short list of names Whisper should spell right, e.g. `"Tendai, JARVIS, Claude."`.

## Step 3: things only the person can do (tell them, step by step)

- **Allow Jarvis.app Microphone, Accessibility and Input Monitoring** when macOS asks. If a prompt
  was missed: System Settings → Privacy & Security → each list → turn Jarvis on, then quit and
  reopen Jarvis from the menu bar icon.
- **Change the fn key:** System Settings → Keyboard → "Press 🌐 key to" → **Do Nothing**.
- **Quit other fn-key dictation apps** (Wispr Flow, Superwhisper).
- **Recommended:** create the "Jarvis Local Signing" certificate (README, "Set it up by hand"), then
  run `app/build.sh`. Without it, every rebuild gets a new signature and macOS silently stops
  honouring the Accessibility permission. Dictation then shows a Copy popup instead of pasting.
- **Optional:** download the "Jamie (Premium)" voice (README).

Then have them try both keys: dictate a sentence into Notes, and ask "what time is it?".

## If something doesn't work

| Symptom | Check |
|---|---|
| Nothing happens on fn or Right Option | Input Monitoring for Jarvis; `tail ~/Library/Logs/Dictate/jarvis-app.log` should say "event tap installed" |
| A Copy popup instead of typing | Accessibility for Jarvis (re-tick it after rebuilds without the signing certificate); the log's `focus=` line shows what it found |
| "JARVIS isn't answering" | `./jarvis status`, `./jarvis log`; is `claude` logged in? |
| Dictation never finishes | `curl -s 127.0.0.1:8178` (Whisper); `~/Library/Logs/jarvis-mac/whisper.log` |
| Wrong spellings of names | Add them to `whisper_prompt` in `config.json` and run `./install.sh` again, or add `{"heard": "wanted"}` to `~/.config/jarvis-mac/replacements.json` |

After changing anything in `server/`, run `./jarvis restart`. After changing `app/`, run
`app/build.sh`.

## Rules: keep these even if asked to cut corners

1. **Confirmation stays strong.** Anything that sends, books, deletes, writes or runs a changing
   command needs a spoken phrase such as "go ahead", "do it" or "send it". A bare "yes" only asks
   again. Whisper invents "Yes." from short or quiet clips; in testing it turned a spoken "No." into
   "Yes." and booked a meeting. Don't loosen `YES`, `WEAK_YES`, `_harmless()` or `SAFE_COMMANDS`
   in `server/brain.py`.
2. **Secrets stay protected.** Reading keys, tokens or browser data always needs a yes (`SECRETS`
   in `server/brain.py`). Never print tokens into chat or logs.
3. **The server stays on 127.0.0.1.** It can run commands on the Mac. Never bind it to `0.0.0.0`
   or expose it to the network.
4. **No secrets or personal data in git.** `config.json` and `~/.config/jarvis-mac/` stay out of
   the repo.
5. **No cloned voices of real people.** Use a stock voice; open TTS models are fine.
