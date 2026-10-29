# JARVIS for your Mac

A voice assistant and a dictation app for your Mac, with Claude Code as the brain.

<img src="docs/reactor.gif" width="200" align="right" alt="The JARVIS reactor: listening, thinking, speaking">

- **Dictate anywhere:** hold **fn** and talk, then let go, and the text is typed into whatever app you're in.
  Double-tap fn for hands-free; tap fn again to finish. Speech-to-text is Whisper running on your
  Mac, so your voice never leaves it.
- **Ask JARVIS:** hold **Right Option** and ask, or double-tap it and just talk. It answers out loud in a
  calm British voice, with a reactor on screen that listens, thinks and speaks with you.
- **Talk back and forth:** after an answer it keeps listening for a few seconds, so you can just reply.
  It starts speaking as soon as the first sentence of its answer is ready, and says what it's doing
  ("Checking your calendar.") while it looks things up. Say "that's all" to finish.
- **One conversation all day:** it remembers what you talked about today, so "it" and "that" still
  work later. Say "start fresh" to clear it.
- **It knows what's on screen:** the app you're in, its window title and any selected text. Select an
  error and ask "what does this mean?".
- **It can look things up:**
  - your calendar, email, Google Drive, Slack and Jira, through the claude.ai connectors you've
    set up
  - your Mac: files, battery, disk space, what's running
  - the web
- **It can do things,** but only after you say **"go ahead"**: book meetings, send emails and
  messages, write or delete files, quit apps, change settings, run commands. A bare "yes" isn't
  enough, because speech-to-text sometimes hears "No." as "Yes."
- **Cut in:** press Right Option while it's talking or thinking and ask something else. **Esc**
  just stops it talking.
- **Meeting reminders:** five minutes before each meeting, if Google Calendar is connected. Turn
  them off from the menu bar icon.
- **Follow a T3 Code session** (if you use T3 Code): say "follow the scraper session". When it finishes,
  fails or needs you, JARVIS tells you what it said in a sentence or two, then listens for your reply.

There are no API keys to manage: it uses your own Claude Code login.

## What you need

- **A Mac with Apple Silicon** (M1 or later), macOS 13 or later, and about 1 GB of free disk space.
- **[Homebrew](https://brew.sh)** and the Xcode command line tools (`xcode-select --install`).
- **[Claude Code](https://claude.com/claude-code)**, installed and logged in with your own Claude
  plan. JARVIS's answers count against that plan's usage.
- **Optional:** connectors for Google Calendar, Gmail, Google Drive, Slack and Jira, connected in
  claude.ai → Settings → Connectors. Without them JARVIS still works for your Mac and the web.

## Set it up (the easy way)

Clone this repo, open it in Claude Code, and say:

> Read AGENTS.md and set up JARVIS on my Mac.

It will ask for your name and city, run the install, and tell you which macOS permissions to tick.

## Set it up (by hand)

```bash
git clone https://github.com/AvocadoCease/jarvis-mac.git && cd jarvis-mac
cp config.example.json config.json      # your name, city and time zone
./install.sh                            # Whisper, the background server, Jarvis.app
./jarvis status
```

Then:
1. **When macOS asks, allow Jarvis.app Microphone, Accessibility and Input Monitoring.** If you
   missed a prompt, go to System Settings → Privacy & Security, turn Jarvis on in each list, and
   reopen the app.
2. **Change what the fn key does:** System Settings → Keyboard → "Press 🌐 key to" → **Do Nothing**.
3. **Quit any other dictation app that uses fn,** such as Wispr Flow or Superwhisper.
4. **Optional, for a better voice:** System Settings → Accessibility → Spoken Content → System voice
   → Manage Voices, and download **Jamie (Premium)**. JARVIS uses it automatically.

**Recommended:** create a signing certificate once, so macOS doesn't forget Jarvis's permissions
every time it's rebuilt:
1. Open Keychain Access → Certificate Assistant → Create a Certificate.
2. Name it `Jarvis Local Signing`, set Identity Type to Self Signed Root and Certificate Type to
   Code Signing.
3. Run `app/build.sh` again and grant the permissions one last time.

## Using it

| Do this | To |
|---|---|
| Hold **fn**, talk, let go | Dictate into the app you're in |
| Double-tap **fn**, talk, tap fn | Dictate hands-free |
| Hold **Right Option**, ask, let go | Ask JARVIS |
| Double-tap **Right Option**, talk | Ask without holding (it stops when you pause) |
| Just reply after an answer | Carry on the conversation ("that's all" or **Esc** ends it) |
| Press **Right Option** while it talks or thinks | Cut in with a new question |
| **Esc** while it talks or listens | Stop it talking or listening |
| Say **"go ahead"** / **"cancel"** | Answer when it asks "Shall I go ahead?" |

Some things to try:
- "What's on my calendar tomorrow?"
- "Any emails from Sam today?"
- "How much disk space do I have?"
- "Find the PDF I downloaded yesterday."
- "Open Spotify."
- "Book a call with Sam at 10 tomorrow, half an hour."
- "What does this mean?" (with an error message selected)
- "Follow the scraper session." (with T3 Code)

If dictation shows a **Copy** popup instead of typing, it couldn't find a text box to type into.
The text is also saved in the menu bar icon's Recent list.

## Files

| Path | What it is |
|---|---|
| `app/` | Jarvis.app: dictation, "ask JARVIS" and the reactor (`Sources/main.swift`, `Sources/Reactor.swift`) |
| `server/serve.py` | The background server on 127.0.0.1:8787. It only listens on your Mac, never the network. |
| `server/brain.py` | A warm Claude Code process, the "go ahead" confirmations and what it may do on your Mac |
| `server/voice.py` | JARVIS's voice (macOS `say` and ffmpeg) |
| `server/announce.py` | Meeting reminders, and T3 Code session updates if you use T3 Code |
| `config.json` | Your settings (not in git) |
| `./jarvis` | `status`, `restart`, `log`, `stop`, `start` for the server |

Logs are in `~/Library/Logs/jarvis-mac/` and `~/Library/Logs/Dictate/jarvis-app.log`.

## Limitations

- **Apple Silicon Macs only.**
- **English only.** Whisper runs with `-l en`.
- **Answers take about 2–6 seconds;** dictation is near-instant.
- **The voice is macOS `say`.** It's clear but a little robotic.
- **No "Hey JARVIS" wake word yet.** Hold or double-tap Right Option to start.
- **You can't talk over it.** Press Right Option to cut in instead.
- **Keeping listening after answers can pick up a loud TV or radio.** Turn it off from the menu bar icon
  ("Keep listening after answers").

There's a sibling project for TVs: [jarvis-tv](https://github.com/AvocadoCease/jarvis-tv).

## Licence

MIT (see `LICENSE`). JARVIS and Iron Man belong to Marvel; this is a fan project. The reactor
animation is drawn in code, in the style of the films.
