"""Your settings, read from config.json at the top of the project (copy config.example.json).

Everything personal lives there: your name and where you are. Nothing here needs editing.
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PATH = os.environ.get("JARVIS_CONFIG", os.path.join(ROOT, "config.json"))

DEFAULTS = {
    "user_name": "there",
    "place": "London",
    "timezone": "Europe/London",
    "claude_config_dir": "",
    "t3": {"provider": "", "model": ""},
}


def _load():
    cfg = json.loads(json.dumps(DEFAULTS))
    try:
        with open(PATH, encoding="utf-8") as f:
            mine = json.load(f)
    except FileNotFoundError:
        print(f"settings: no {PATH}; using defaults (copy config.example.json to config.json)", flush=True)
        return cfg
    for key, value in mine.items():
        if isinstance(value, dict) and isinstance(cfg.get(key), dict):
            cfg[key].update(value)
        else:
            cfg[key] = value
    return cfg


C = _load()
USER_NAME = C["user_name"]
PLACE, TIMEZONE = C["place"], C["timezone"]
CLAUDE_CONFIG_DIR = os.path.expanduser(C["claude_config_dir"]) if C["claude_config_dir"] else ""
T3 = C["t3"]
