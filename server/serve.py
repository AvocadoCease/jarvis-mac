"""The JARVIS server for the Mac app. Listens on this Mac only (127.0.0.1), never the network.

  python3 server/serve.py            # http://127.0.0.1:8787

Routes:
  /api/command?text=   ask JARVIS anything (see brain.py): {"ok", "reply", "confirm"?, "details"?}
  /api/ask?text=       the same, streamed as JSON lines while JARVIS works: {"type": "status"|"say", "text"},
                       then {"type": "done", ...the /api/command answer, "speak": what's still to be said}.
                       &app=&window=&selected= say what's on screen. "Start fresh" clears the day's conversation
  /api/follow          the T3 session JARVIS follows: ?thread=&title= to follow, ?stop=1 to stop
  /api/interrupt       stop the answer JARVIS is working on (the app stops its own audio)
  /api/tts?text=       JARVIS's voice as MP3 (see voice.py)
  /api/announce?after=N  new announcements for the app to say (see announce.py);
                       ?on=1|0 turns them on/off; ?test=text queues one; ?status=1 adds what's coming up
  /api/status          is it up, and is Claude ready
"""
import argparse
import json
import os
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # works under python -I
import announce  # noqa: E402
import brain  # noqa: E402
import voice  # noqa: E402


# "Start fresh", "new conversation", "forget everything": clear the day's conversation (brain.forget)
FRESH_START = re.compile(r"\b(start (afresh|fresh|over)|fresh start|clean slate|(start a )?new conversation|"
                         r"forget (everything|what i (said|asked)|our conversation|this conversation))\b", re.I)


def answer(text, emit=None, screen=None):
    """One question for JARVIS (the brain), unless it's "start fresh"."""
    if FRESH_START.search(text) and not brain.pending():
        brain.forget()
        return {"ok": True, "reply": "Very well. A clean slate."}
    return brain.ask(text, source="mac", emit=emit, screen=screen)


class Handler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def ask_stream(self, arg):
        """/api/ask: answer like /api/command, sending each sentence as soon as it's written."""
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        lock, gone = threading.Lock(), []

        def line(obj):
            if gone:
                return
            try:
                with lock:
                    self.wfile.write((json.dumps(obj) + "\n").encode())
                    self.wfile.flush()
            except OSError:   # the app hung up (you cut in); the answer carries on unheard
                gone.append(True)

        text = arg("text").strip()[:500]
        screen = {k: arg(k)[:2000] for k in ("app", "window", "selected")}
        try:
            result = (answer(text, emit=lambda kind, t: line({"type": kind, "text": t}), screen=screen) if text
                      else {"ok": False, "reply": f"Yes, {brain.USER_NAME}?"})
        except Exception as e:
            result = {"ok": False, "reply": f"I couldn't do that: {e}."}
        line(dict(result, type="done", speak=result.get("speak", result.get("reply", ""))))

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        arg = lambda name: q.get(name, [""])[0]  # noqa: E731
        if url.path == "/api/ask":
            return self.ask_stream(arg)
        try:
            if url.path == "/api/command":
                text = arg("text").strip()[:500]
                if not text:
                    return self.send_json({"ok": False, "reply": f"Yes, {brain.USER_NAME}?"})
                self.send_json(answer(text))
            elif url.path == "/api/follow":
                if "stop" in q:
                    self.send_json({"ok": True, "was": announce.unfollow()})
                else:
                    if arg("thread"):
                        announce.follow(arg("thread"), arg("title")[:200])
                    self.send_json({"ok": True, "following": announce.following()})
            elif url.path == "/api/interrupt":
                self.send_json({"ok": True, "stopped": brain.interrupt()})
            elif url.path == "/api/tts":
                with open(voice.synth(arg("text")), "rb") as f:
                    data = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "audio/mpeg")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            elif url.path == "/api/announce":
                if "on" in q:
                    brain.set_setting("announce", arg("on") in ("1", "true", "on"))
                if "test" in q:   # try it: curl "http://127.0.0.1:8787/api/announce?test=Hello"
                    announce._push(arg("test")[:300])
                after = arg("after")
                self.send_json(dict(announce.since(int(after) if after.lstrip("-").isdigit() else None),
                                    **({"status": announce.status()} if "status" in q else {})))
            elif url.path == "/api/status":
                w = brain._worker["w"]
                self.send_json({"ok": True, "claude_ready": bool(w and w.alive()), "user": brain.USER_NAME})
            else:
                self.send_json({"ok": False, "error": "unknown route"}, 404)
        except Exception as e:
            self.send_json({"ok": False, "error": str(e)}, 500)

    def log_message(self, fmt, *args):
        if not self.path.startswith(("/api/announce", "/api/status")):
            super().log_message(fmt, *args)


class Server(ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        if isinstance(sys.exc_info()[1], (BrokenPipeError, ConnectionResetError)):
            return   # the app hung up mid-answer (cut in): not an error
        super().handle_error(request, client_address)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8787)
    args = ap.parse_args()
    print(f"JARVIS server on http://127.0.0.1:{args.port}", flush=True)
    os.environ["JARVIS_PORT"] = str(args.port)   # so the brain's tools (workmcp) can reach us
    brain.warm_up()  # start Claude now so the first question is quick
    # and have the voice ready for what JARVIS says while it works
    threading.Thread(target=lambda: [voice.synth(p) for p in brain.STATUS_PHRASES + ["Shall I go ahead?"]],
                     daemon=True).start()
    announce.start()
    Server(("127.0.0.1", args.port), Handler).serve_forever()
