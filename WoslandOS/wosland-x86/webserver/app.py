#!/usr/bin/env python3
"""
WoslandOS Web Control Panel
Runs on port 8080 — lets you manage the wosbot service and update the bot token.
"""

import os
import subprocess
import json
from pathlib import Path
from flask import Flask, render_template_string, request, redirect, url_for, jsonify

app = Flask(__name__)

# ── Config (injected via environment by systemd) ──────────────
SERVICE_NAME = os.environ.get("SERVICE_NAME", "wosbot")
BOT_DIR      = os.environ.get("BOT_DIR", "/home/wosland/bot")
TOKEN_FILE   = os.environ.get("TOKEN_FILE", f"{BOT_DIR}/bot_token.txt")
PORT         = int(os.environ.get("PORT", "8080"))

# ── Helpers ───────────────────────────────────────────────────
def run(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.returncode, result.stdout.strip(), result.stderr.strip()

def service_status():
    code, out, _ = run(f"systemctl is-active {SERVICE_NAME}")
    return out  # "active", "inactive", "failed", etc.

def service_info():
    _, out, _ = run(f"systemctl status {SERVICE_NAME} --no-pager -l")
    return out

def read_token():
    try:
        return Path(TOKEN_FILE).read_text().strip()
    except Exception:
        return ""

def write_token(token: str):
    Path(TOKEN_FILE).write_text(token.strip() + "\n")
    os.chmod(TOKEN_FILE, 0o640)

def get_logs(lines=80):
    _, out, _ = run(f"journalctl -u {SERVICE_NAME} -n {lines} --no-pager --output=short-iso")
    return out

# ── HTML template ─────────────────────────────────────────────
HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WoslandOS Control Panel</title>
  <style>
    :root {
      --bg: #0d1117; --card: #161b22; --border: #30363d;
      --text: #e6edf3; --muted: #8b949e; --green: #3fb950;
      --red: #f85149; --yellow: #d29922; --blue: #58a6ff;
      --accent: #1f6feb;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; min-height: 100vh; }
    header { background: var(--card); border-bottom: 1px solid var(--border); padding: 16px 32px; display: flex; align-items: center; gap: 16px; }
    header img { height: 40px; border-radius: 6px; }
    header h1 { font-size: 1.3rem; font-weight: 600; }
    header span { color: var(--muted); font-size: 0.85rem; }
    main { max-width: 900px; margin: 0 auto; padding: 32px 16px; display: grid; gap: 24px; }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 24px; }
    .card h2 { font-size: 1rem; font-weight: 600; margin-bottom: 16px; color: var(--blue); display: flex; align-items: center; gap: 8px; }
    .status-pill { display: inline-flex; align-items: center; gap: 6px; padding: 4px 12px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; }
    .status-pill.active   { background: rgba(63,185,80,.15); color: var(--green); }
    .status-pill.inactive { background: rgba(248,81,73,.15); color: var(--red); }
    .status-pill.failed   { background: rgba(248,81,73,.15); color: var(--red); }
    .status-pill.unknown  { background: rgba(139,148,158,.15); color: var(--muted); }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }
    .btn-row { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 16px; }
    button { cursor: pointer; border: none; border-radius: 8px; padding: 8px 18px; font-size: 0.9rem; font-weight: 600; transition: opacity .15s; }
    button:hover { opacity: .8; }
    .btn-start   { background: var(--green); color: #000; }
    .btn-stop    { background: var(--red); color: #fff; }
    .btn-restart { background: var(--yellow); color: #000; }
    .btn-save    { background: var(--accent); color: #fff; }
    .btn-refresh { background: var(--border); color: var(--text); }
    textarea, input[type=text], input[type=password] {
      width: 100%; background: #010409; border: 1px solid var(--border);
      border-radius: 8px; color: var(--text); padding: 10px 14px;
      font-size: 0.9rem; font-family: monospace; resize: vertical;
    }
    textarea { min-height: 260px; }
    .log-box { background: #010409; border: 1px solid var(--border); border-radius: 8px; padding: 14px; font-family: monospace; font-size: 0.78rem; white-space: pre-wrap; overflow-y: auto; max-height: 360px; color: #7ee787; }
    label { display: block; margin-bottom: 8px; font-size: 0.88rem; color: var(--muted); }
    .info-row { display: flex; justify-content: space-between; align-items: center; }
    .flash { padding: 10px 16px; border-radius: 8px; margin-bottom: 12px; font-size: 0.9rem; }
    .flash.ok  { background: rgba(63,185,80,.15); color: var(--green); border: 1px solid var(--green); }
    .flash.err { background: rgba(248,81,73,.15); color: var(--red); border: 1px solid var(--red); }
    @media (max-width: 600px) { header { padding: 12px 16px; } }
  </style>
</head>
<body>
<header>
  <div>
    <h1>⚙️ WoslandOS Control Panel</h1>
    <span>WoslandOS Bot Service Manager</span>
  </div>
</header>

<main>
  {% if msg %}
  <div class="flash {{ 'ok' if ok else 'err' }}">{{ msg }}</div>
  {% endif %}

  <!-- Service Status -->
  <div class="card">
    <div class="info-row">
      <h2>🤖 WOSBot Service</h2>
      <span class="status-pill {{ status }}"><span class="dot"></span>{{ status }}</span>
    </div>
    <div class="btn-row">
      <form method="post" action="/service/start">
        <button class="btn-start" type="submit">▶ Start</button>
      </form>
      <form method="post" action="/service/stop">
        <button class="btn-stop" type="submit">■ Stop</button>
      </form>
      <form method="post" action="/service/restart">
        <button class="btn-restart" type="submit">↺ Restart</button>
      </form>
    </div>
  </div>

  <!-- Bot Token -->
  <div class="card">
    <h2>🔑 Bot Token</h2>
    <form method="post" action="/token">
      <label for="token">Current token stored in <code>bot_token.txt</code></label>
      <input type="text" id="token" name="token" value="{{ token }}" placeholder="Paste your bot token here..." autocomplete="off">
      <div class="btn-row">
        <button class="btn-save" type="submit">💾 Save Token</button>
      </div>
    </form>
  </div>

  <!-- Live Logs -->
  <div class="card">
    <div class="info-row">
      <h2>📋 Recent Logs</h2>
      <form method="get" action="/">
        <button class="btn-refresh" type="submit">⟳ Refresh</button>
      </form>
    </div>
    <div class="log-box" id="logbox">{{ logs }}</div>
  </div>

  <!-- System Info -->
  <div class="card">
    <h2>🖥️ Service Details</h2>
    <div class="log-box">{{ svc_info }}</div>
  </div>
</main>

<script>
  // Auto-scroll log to bottom
  const lb = document.getElementById('logbox');
  if(lb) lb.scrollTop = lb.scrollHeight;
</script>
</body>
</html>
"""

# ── Routes ────────────────────────────────────────────────────
@app.route("/")
def index():
    msg = request.args.get("msg", "")
    ok  = request.args.get("ok", "1") == "1"
    return render_template_string(HTML,
        status=service_status(),
        token=read_token(),
        logs=get_logs(),
        svc_info=service_info(),
        msg=msg, ok=ok
    )

@app.route("/service/<action>", methods=["POST"])
def service_action(action):
    if action not in ("start", "stop", "restart"):
        return redirect(url_for("index", msg="Unknown action", ok=0))
    code, _, err = run(f"systemctl {action} {SERVICE_NAME}")
    if code == 0:
        return redirect(url_for("index", msg=f"Service {action}ed successfully.", ok=1))
    return redirect(url_for("index", msg=f"Error: {err}", ok=0))

@app.route("/token", methods=["POST"])
def update_token():
    token = request.form.get("token", "").strip()
    if not token:
        return redirect(url_for("index", msg="Token cannot be empty.", ok=0))
    try:
        write_token(token)
        # Restart service so the new token is picked up
        run(f"systemctl restart {SERVICE_NAME}")
        return redirect(url_for("index", msg="Token saved and service restarted.", ok=1))
    except Exception as e:
        return redirect(url_for("index", msg=f"Failed to save token: {e}", ok=0))

@app.route("/api/status")
def api_status():
    return jsonify({
        "service": service_status(),
        "token_set": bool(read_token()),
    })

@app.route("/api/logs")
def api_logs():
    n = int(request.args.get("lines", 100))
    return jsonify({"logs": get_logs(n)})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, debug=False)
