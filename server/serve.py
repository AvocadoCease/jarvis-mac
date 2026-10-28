"""The JARVIS server for the Mac app. Listens on this Mac only (127.0.0.1), never the network.

  python3 server/serve.py            # http://127.0.0.1:8787

Routes:
  /api/command?text=   ask JARVIS anything (see brain.py): {"ok", "reply", "confirm"?, "details"?}
  /api/interrupt       stop the answer JARVIS is working on (the app stops its own audio)
  /api/tts?text=       JARVIS's voice as MP3 (see voice.py)
  /api/announce?after=N  new announcements for the app to say (see announce.py);
                       ?on=1|0 turns them on/off; ?test=text queues one; ?status=1 adds what's coming up
  /api/status          is it up, and is Claude ready
"""
import argparse
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # works under python -I
import announce  # noqa: E402
import brain  # noqa: E402
import voice  # noqa: E402


class Handler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        arg = lambda name: q.get(name, [""])[0]  # noqa: E731
        try:
            if url.path == "/api/command":
                text = arg("text").strip()[:500]
                if not text:
                    return self.send_json({"ok": False, "reply": f"Yes, {brain.USER_NAME}?"})
                self.send_json(brain.ask(text, source="mac"))
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
    brain.warm_up()  # start Claude now so the first question is quick
    announce.start()
    Server(("127.0.0.1", args.port), Handler).serve_forever()
