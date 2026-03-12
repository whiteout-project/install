#!/usr/bin/env python3
"""
WoslandOS Web Control Panel
Manages WOSBot service, bot switching, token, desktop GUI toggle.
"""

import os, subprocess, json, threading
from pathlib import Path
from flask import Flask, jsonify, request, Response

app = Flask(__name__)

SERVICE_NAME  = os.environ.get("SERVICE_NAME", "wosbot")
BOT_DIR       = os.environ.get("BOT_DIR",      "/home/wosland/bot")
TOKEN_FILE    = os.environ.get("TOKEN_FILE",   "/home/wosland/bot/bot_token.txt")
PORT          = int(os.environ.get("PORT",     "8080"))
SWITCH_SCRIPT = "/usr/local/bin/wosland-switch-bot.sh"
BOT_TYPE_FILE = f"{BOT_DIR}/.bot_type"
JS_ENV_FILE   = f"{BOT_DIR}/src/.env"
DESKTOP_FLAG  = "/etc/wosland/gui_enabled"

switch_lock   = threading.Lock()
switch_status = {"running": False, "log": [], "result": None}


def run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return (r.stdout + r.stderr).strip()
    except Exception as e:
        return str(e)


def service_status():
    r = subprocess.run(["systemctl", "is-active", SERVICE_NAME],
                       capture_output=True, text=True)
    return r.stdout.strip()


def read_token():
    if Path(TOKEN_FILE).exists():
        t = Path(TOKEN_FILE).read_text().strip()
        if t:
            return t
    if Path(JS_ENV_FILE).exists():
        for line in Path(JS_ENV_FILE).read_text().splitlines():
            if line.startswith("TOKEN="):
                return line[6:].strip()
    return ""


def get_bot_type():
    if Path(BOT_TYPE_FILE).exists():
        return Path(BOT_TYPE_FILE).read_text().strip()
    return "wos-py"


def gui_enabled():
    return Path(DESKTOP_FLAG).exists()


def get_recent_logs(n=80):
    try:
        r = subprocess.run(
            ["journalctl", "-u", SERVICE_NAME, "-n", str(n), "--no-pager", "--output=short"],
            capture_output=True, text=True, timeout=5)
        return r.stdout
    except Exception:
        return ""


def do_switch(bot_type):
    global switch_status
    switch_status = {"running": True, "log": [], "result": None}
    try:
        proc = subprocess.Popen(
            ["bash", SWITCH_SCRIPT, bot_type],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        for line in proc.stdout:
            switch_status["log"].append(line.rstrip())
        proc.wait()
        switch_status["result"] = "ok" if proc.returncode == 0 else "error"
    except Exception as e:
        switch_status["log"].append(str(e))
        switch_status["result"] = "error"
    finally:
        switch_status["running"] = False


# ─────────────────────────────────────────────────────────────
# HTML — full dark-industrial dashboard
# ─────────────────────────────────────────────────────────────
HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>WoslandOS Control Panel</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Exo+2:wght@300;400;600;700&display=swap" rel="stylesheet">
<style>
:root {
  --bg:      #0b0e14;
  --panel:   #111520;
  --border:  #1e2a3a;
  --accent:  #00c8ff;
  --accent2: #ff6b35;
  --green:   #00e676;
  --red:     #ff1744;
  --yellow:  #ffea00;
  --text:    #cdd6f4;
  --muted:   #6c7a96;
  --r:       6px;
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:'Exo 2',sans-serif;font-weight:300;min-height:100vh;overflow-x:hidden}
body::before{content:'';position:fixed;inset:0;z-index:0;background-image:linear-gradient(rgba(0,200,255,.025) 1px,transparent 1px),linear-gradient(90deg,rgba(0,200,255,.025) 1px,transparent 1px);background-size:44px 44px;pointer-events:none}
header{position:relative;z-index:2;display:flex;align-items:center;justify-content:space-between;padding:16px 32px;border-bottom:1px solid var(--border);background:rgba(11,14,20,.96);backdrop-filter:blur(8px)}
.logo{display:flex;align-items:center;gap:12px}
.logo-icon{width:34px;height:34px;background:linear-gradient(135deg,var(--accent),#0050ff);border-radius:7px;display:grid;place-items:center;font-family:'Share Tech Mono',monospace;font-size:13px;font-weight:bold;color:#fff}
.logo-text{font-size:17px;font-weight:600;letter-spacing:2px}
.logo-text span{color:var(--accent)}
.hdr-right{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--muted)}
.dot{width:8px;height:8px;border-radius:50%;background:var(--muted);transition:background .3s}
.dot.active{background:var(--green);box-shadow:0 0 8px var(--green)}
.dot.failed{background:var(--red);box-shadow:0 0 8px var(--red)}

main{position:relative;z-index:1;max-width:1080px;margin:0 auto;padding:28px 20px;display:grid;grid-template-columns:1fr 1fr;gap:18px}
@media(max-width:700px){main{grid-template-columns:1fr}header{padding:14px 16px}}

.card{background:var(--panel);border:1px solid var(--border);border-radius:var(--r);padding:20px 22px;position:relative;overflow:hidden;transition:border-color .2s}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,var(--accent),transparent)}
.card:hover{border-color:rgba(0,200,255,.22)}
.card.full{grid-column:1/-1}
.card-title{font-size:11px;font-weight:700;letter-spacing:3px;color:var(--muted);text-transform:uppercase;margin-bottom:16px;display:flex;align-items:center;gap:7px}
.card-title .ic{color:var(--accent);font-size:13px}

.btn{display:inline-flex;align-items:center;justify-content:center;gap:5px;padding:8px 16px;border:none;border-radius:var(--r);font-family:'Exo 2',sans-serif;font-size:12px;font-weight:600;letter-spacing:1px;cursor:pointer;transition:all .15s;text-transform:uppercase}
.btn:disabled{opacity:.4;cursor:not-allowed}
.btn-primary{background:var(--accent);color:#000}
.btn-primary:hover:not(:disabled){background:#33d6ff;transform:translateY(-1px)}
.btn-success{background:var(--green);color:#000}
.btn-success:hover:not(:disabled){background:#33ff91;transform:translateY(-1px)}
.btn-danger{background:var(--red);color:#fff}
.btn-danger:hover:not(:disabled){background:#ff4569}
.btn-warn{background:var(--accent2);color:#000}
.btn-warn:hover:not(:disabled){background:#ff8c5a}
.btn-ghost{background:transparent;color:var(--text);border:1px solid var(--border)}
.btn-ghost:hover:not(:disabled){border-color:var(--accent);color:var(--accent)}
.btn-row{display:flex;flex-wrap:wrap;gap:9px;margin-top:6px}

.svc-row{display:flex;align-items:center;gap:12px;margin-bottom:18px;padding:11px 14px;background:rgba(0,0,0,.3);border-radius:var(--r);border:1px solid var(--border)}
.svc-name{font-family:'Share Tech Mono',monospace;font-size:14px;color:var(--accent)}
.pill{font-family:'Share Tech Mono',monospace;font-size:11px;padding:3px 9px;border-radius:20px;letter-spacing:1px;background:rgba(108,122,150,.18);color:var(--muted);transition:all .3s}
.pill.active{background:rgba(0,230,118,.14);color:var(--green)}
.pill.failed{background:rgba(255,23,68,.14);color:var(--red)}
.pill.inactive{background:rgba(255,234,0,.1);color:var(--yellow)}

.bot-list{display:flex;flex-direction:column;gap:9px;margin-bottom:16px}
.bot-opt{display:flex;align-items:flex-start;gap:11px;padding:11px 13px;border:1px solid var(--border);border-radius:var(--r);cursor:pointer;transition:all .18s;user-select:none}
.bot-opt:hover{border-color:rgba(0,200,255,.38);background:rgba(0,200,255,.04)}
.bot-opt.selected{border-color:var(--accent);background:rgba(0,200,255,.07)}
.bot-opt.current{border-color:var(--green) !important;background:rgba(0,230,118,.05)}
.bot-radio{width:15px;height:15px;border-radius:50%;border:2px solid var(--muted);margin-top:3px;flex-shrink:0;transition:all .2s}
.bot-opt.selected .bot-radio,.bot-opt.current .bot-radio{border-color:var(--accent);background:var(--accent);box-shadow:0 0 6px var(--accent)}
.bot-opt.current .bot-radio{border-color:var(--green);background:var(--green);box-shadow:0 0 6px var(--green)}
.bot-name{font-size:13px;font-weight:600}
.bot-desc{font-size:11px;color:var(--muted);margin-top:3px}
.tag{font-size:10px;padding:2px 5px;border-radius:3px;margin-left:5px;font-family:'Share Tech Mono',monospace}
.tag-py{background:rgba(0,200,255,.14);color:var(--accent)}
.tag-js{background:rgba(255,234,0,.12);color:var(--yellow)}
.tag-on{background:rgba(0,230,118,.12);color:var(--green)}

.inp-wrap{display:flex;gap:7px;margin-bottom:10px}
.tok-inp{flex:1;padding:9px 13px;background:rgba(0,0,0,.4);border:1px solid var(--border);border-radius:var(--r);color:var(--text);font-family:'Share Tech Mono',monospace;font-size:12px;outline:none;transition:border-color .2s}
.tok-inp:focus{border-color:var(--accent)}
.tok-inp::placeholder{color:var(--muted)}

.tgl-row{display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--border)}
.tgl-row:last-child{border-bottom:none}
.tgl-lbl{font-size:13px}
.tgl-sub{font-size:11px;color:var(--muted);margin-top:2px}
.tgl{position:relative;width:44px;height:23px;flex-shrink:0}
.tgl input{display:none}
.tgl-track{position:absolute;inset:0;background:var(--border);border-radius:23px;cursor:pointer;transition:background .2s}
.tgl input:checked+.tgl-track{background:var(--accent)}
.tgl-thumb{position:absolute;top:3px;left:3px;width:17px;height:17px;background:#fff;border-radius:50%;transition:transform .2s;pointer-events:none}
.tgl input:checked~.tgl-thumb{transform:translateX(21px)}

.log-box{background:#050810;border:1px solid var(--border);border-radius:var(--r);padding:12px;height:200px;overflow-y:auto;font-family:'Share Tech Mono',monospace;font-size:11.5px;line-height:1.6;color:#8fbe8f;white-space:pre-wrap}
.log-box::-webkit-scrollbar{width:5px}
.log-box::-webkit-scrollbar-track{background:#050810}
.log-box::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}

/* Modals */
.overlay{display:none;position:fixed;inset:0;z-index:100;background:rgba(5,8,16,.88);backdrop-filter:blur(4px);align-items:center;justify-content:center}
.overlay.open{display:flex}
.modal{background:var(--panel);border:1px solid var(--border);border-radius:10px;padding:30px;max-width:400px;width:90%;position:relative}
.modal::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,var(--accent2),var(--red));border-radius:10px 10px 0 0}
.modal-icon{font-size:38px;text-align:center;margin-bottom:14px}
.modal-title{font-size:17px;font-weight:700;text-align:center;margin-bottom:8px}
.modal-body{font-size:13px;color:var(--muted);text-align:center;line-height:1.65;margin-bottom:22px}
.modal-body strong{color:var(--accent2)}
.modal-btns{display:flex;gap:9px;justify-content:center}

/* Switch overlay */
.sw-overlay{display:none;position:fixed;inset:0;z-index:200;background:rgba(5,8,16,.94);backdrop-filter:blur(6px);align-items:center;justify-content:center;flex-direction:column;gap:18px}
.sw-overlay.open{display:flex}
.spinner{width:46px;height:46px;border:3px solid var(--border);border-top-color:var(--accent);border-radius:50%;animation:spin .8s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.sw-title{font-size:18px;font-weight:600;color:var(--accent)}
.sw-log{width:min(580px,90vw);height:190px;background:#050810;border:1px solid var(--border);border-radius:var(--r);padding:12px;overflow-y:auto;font-family:'Share Tech Mono',monospace;font-size:11.5px;line-height:1.6;color:#8fbe8f;white-space:pre-wrap}

.toast{position:fixed;bottom:22px;right:22px;z-index:300;padding:11px 18px;border-radius:var(--r);font-size:13px;font-weight:600;transform:translateY(70px);opacity:0;transition:all .28s}
.toast.show{transform:translateY(0);opacity:1}
.toast.ok{background:var(--green);color:#000}
.toast.err{background:var(--red);color:#fff}
.toast.info{background:var(--accent);color:#000}
</style>
</head>
<body>
<header>
  <div class="logo">
    <div class="logo-icon">W</div>
    <div class="logo-text">Wosland<span>OS</span></div>
  </div>
  <div class="hdr-right">
    <div class="dot" id="hdr-dot"></div>
    <span id="hdr-status">checking...</span>
  </div>
</header>

<main>
  <!-- Service Control -->
  <div class="card">
    <div class="card-title"><span class="ic">⚡</span> Service Control</div>
    <div class="svc-row">
      <span class="svc-name" id="svc-name">wosbot</span>
      <span class="pill" id="svc-status">...</span>
      <span style="margin-left:auto;font-size:11px;color:var(--muted)" id="bot-badge">—</span>
    </div>
    <div class="btn-row">
      <button class="btn btn-success" onclick="svcAction('start')">▶ Start</button>
      <button class="btn btn-danger"  onclick="svcAction('stop')">■ Stop</button>
      <button class="btn btn-warn"    onclick="svcAction('restart')">↺ Restart</button>
    </div>
  </div>

  <!-- Token -->
  <div class="card">
    <div class="card-title"><span class="ic">🔑</span> Bot Token</div>
    <div class="inp-wrap">
      <input id="tok" class="tok-inp" type="password" placeholder="Paste bot token…" autocomplete="off">
      <button class="btn btn-ghost" onclick="toggleVis()">👁</button>
    </div>
    <div class="btn-row">
      <button class="btn btn-primary" onclick="saveToken()">Save &amp; Restart</button>
      <button class="btn btn-ghost"   onclick="loadToken()">Load Current</button>
    </div>
    <p style="font-size:11px;color:var(--muted);margin-top:10px" id="tok-note">
      Saved to the correct location for the active bot.
    </p>
  </div>

  <!-- Bot Selection -->
  <div class="card full">
    <div class="card-title"><span class="ic">🤖</span> Bot Selection</div>
    <div class="bot-list">
      <div class="bot-opt" data-bot="wos-py" onclick="selectBot(this)">
        <div class="bot-radio"></div>
        <div>
          <div class="bot-name">Whiteout Survival <span class="tag tag-py">PYTHON</span><span class="tag tag-on">DEFAULT</span></div>
          <div class="bot-desc">Alliance management, gift codes &amp; event notifications — original Python edition</div>
        </div>
      </div>
      <div class="bot-opt" data-bot="wos-js" onclick="selectBot(this)">
        <div class="bot-radio"></div>
        <div>
          <div class="bot-name">Whiteout Survival <span class="tag tag-js">NODE 22</span></div>
          <div class="bot-desc">JavaScript/TypeScript edition — token stored in <code style="color:var(--accent)">src/.env</code></div>
        </div>
      </div>
      <div class="bot-opt" data-bot="kingshot" onclick="selectBot(this)">
        <div class="bot-radio"></div>
        <div>
          <div class="bot-name">Kingshot <span class="tag tag-py">PYTHON</span></div>
          <div class="bot-desc">Alliance management, gift codes &amp; events for the Kingshot game</div>
        </div>
      </div>
    </div>
    <div class="btn-row">
      <button class="btn btn-primary" id="sw-btn" onclick="requestSwitch()" disabled>Switch Bot</button>
      <span style="font-size:11px;color:var(--muted);align-self:center" id="sw-note">Select a different bot to enable switching</span>
    </div>
  </div>

  <!-- Desktop -->
  <div class="card">
    <div class="card-title"><span class="ic">🖥</span> Desktop &amp; GUI</div>
    <div class="tgl-row">
      <div>
        <div class="tgl-lbl">Desktop GUI on boot</div>
        <div class="tgl-sub">Enable / disable graphical interface autostart</div>
      </div>
      <label class="tgl">
        <input type="checkbox" id="gui-tgl" onchange="setGui(this.checked)">
        <div class="tgl-track"></div>
        <div class="tgl-thumb"></div>
      </label>
    </div>
    <div style="margin-top:14px;padding-top:12px;border-top:1px solid var(--border)">
      <div style="font-size:11px;color:var(--muted);margin-bottom:8px">Quick Links</div>
      <div class="btn-row">
        <button class="btn btn-ghost" style="font-size:11px"
                onclick="window.open('http://'+location.hostname+':@@PORT@@','_blank')">
          ⧉ Open Web Panel
        </button>
      </div>
    </div>
  </div>

  <!-- Logs -->
  <div class="card">
    <div class="card-title">
      <span class="ic">📋</span> Recent Logs
      <button class="btn btn-ghost" style="margin-left:auto;font-size:10px;padding:3px 9px" onclick="loadLogs()">↺</button>
    </div>
    <div class="log-box" id="log-box">Loading...</div>
  </div>
</main>

<!-- Modal 1 -->
<div class="overlay" id="m1">
  <div class="modal">
    <div class="modal-icon">⚠️</div>
    <div class="modal-title">Switch Bot?</div>
    <div class="modal-body">Switching to <strong id="m1-tgt"></strong>.<br>The current bot will be <strong>stopped and all its files removed</strong>.<br>Your token will be carried over automatically.</div>
    <div class="modal-btns">
      <button class="btn btn-ghost" onclick="closeM1()">Cancel</button>
      <button class="btn btn-warn"  onclick="openM2()">Continue →</button>
    </div>
  </div>
</div>

<!-- Modal 2 -->
<div class="overlay" id="m2">
  <div class="modal">
    <div class="modal-icon">🚨</div>
    <div class="modal-title">Are you absolutely sure?</div>
    <div class="modal-body">This will <strong>delete all bot files</strong> and install <strong id="m2-tgt"></strong> from scratch.<br><br>The service will be unavailable for several minutes. This cannot be undone.</div>
    <div class="modal-btns">
      <button class="btn btn-ghost"  onclick="closeM2()">Cancel</button>
      <button class="btn btn-danger" onclick="confirmSwitch()">Yes, Switch Now</button>
    </div>
  </div>
</div>

<!-- Switch overlay -->
<div class="sw-overlay" id="sw-ov">
  <div class="spinner"></div>
  <div class="sw-title">Switching bot… please wait</div>
  <div class="sw-log" id="sw-log"></div>
</div>

<div class="toast" id="toast"></div>

<script>
const LABELS = {'wos-py':'Whiteout Survival (Python)','wos-js':'Whiteout Survival (JS)','kingshot':'Kingshot'};
let selBot=null, curBot=null, pollTimer=null;

function toast(msg,t='info'){const e=document.getElementById('toast');e.textContent=msg;e.className='toast show '+t;setTimeout(()=>e.className='toast',2900)}

async function fetchStatus(){
  try{
    const d=await (await fetch('/api/status')).json();
    const s=d.status;
    document.getElementById('svc-status').textContent=s;
    document.getElementById('svc-status').className='pill '+(s==='active'?'active':s==='failed'?'failed':'inactive');
    document.getElementById('hdr-dot').className='dot '+(s==='active'?'active':s==='failed'?'failed':'');
    document.getElementById('hdr-status').textContent=s==='active'?'Running':s==='failed'?'Failed':'Stopped';
    document.getElementById('svc-name').textContent=d.service;
    curBot=d.bot_type;
    document.getElementById('bot-badge').textContent=LABELS[curBot]||curBot;
    document.querySelectorAll('.bot-opt').forEach(el=>{
      el.classList.toggle('current', el.dataset.bot===curBot);
      if(el.dataset.bot===curBot&&!selBot) el.classList.add('selected');
    });
    document.getElementById('gui-tgl').checked=d.gui_enabled;
    updateSwBtn();
  }catch(e){}
}

async function svcAction(a){
  try{const d=await(await fetch('/api/service/'+a,{method:'POST'})).json();toast(d.message,d.ok?'ok':'err');setTimeout(fetchStatus,1600)}
  catch(e){toast('Request failed','err')}
}

async function loadToken(){
  try{const d=await(await fetch('/api/token')).json();document.getElementById('tok').value=d.token||'';toast('Token loaded','info')}
  catch(e){toast('Load failed','err')}
}
async function saveToken(){
  const v=document.getElementById('tok').value.trim();
  if(!v){toast('Token cannot be empty','err');return}
  try{const d=await(await fetch('/api/token',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:v})})).json();toast(d.message,d.ok?'ok':'err');setTimeout(fetchStatus,2000)}
  catch(e){toast('Save failed','err')}
}
function toggleVis(){const i=document.getElementById('tok');i.type=i.type==='password'?'text':'password'}

function selectBot(el){
  document.querySelectorAll('.bot-opt').forEach(e=>e.classList.remove('selected'));
  el.classList.add('selected'); selBot=el.dataset.bot; updateSwBtn();
}
function updateSwBtn(){
  const diff=selBot&&selBot!==curBot;
  document.getElementById('sw-btn').disabled=!diff;
  document.getElementById('sw-note').textContent=diff?`${LABELS[curBot]||curBot} → ${LABELS[selBot]}`:'Select a different bot to enable switching';
}

function requestSwitch(){if(!selBot||selBot===curBot)return;document.getElementById('m1-tgt').textContent=LABELS[selBot];document.getElementById('m1').classList.add('open')}
function closeM1(){document.getElementById('m1').classList.remove('open')}
function openM2(){closeM1();document.getElementById('m2-tgt').textContent=LABELS[selBot];document.getElementById('m2').classList.add('open')}
function closeM2(){document.getElementById('m2').classList.remove('open')}

async function confirmSwitch(){
  closeM2();
  document.getElementById('sw-ov').classList.add('open');
  document.getElementById('sw-log').textContent='';
  try{
    await fetch('/api/switch',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bot:selBot})});
    pollTimer=setInterval(pollSwitch,1000);
  }catch(e){document.getElementById('sw-ov').classList.remove('open');toast('Switch failed to start','err')}
}
async function pollSwitch(){
  try{
    const d=await(await fetch('/api/switch/status')).json();
    const box=document.getElementById('sw-log');
    box.textContent=d.log.join('\n');box.scrollTop=box.scrollHeight;
    if(!d.running){
      clearInterval(pollTimer);
      setTimeout(()=>{
        document.getElementById('sw-ov').classList.remove('open');
        if(d.result==='ok'){toast('Bot switched!','ok');selBot=null;fetchStatus();loadLogs()}
        else toast('Switch failed — check logs','err');
      },1200);
    }
  }catch(e){}
}

async function setGui(en){
  try{const d=await(await fetch('/api/gui',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({enabled:en})})).json();toast(d.message,d.ok?'ok':'err')}
  catch(e){toast('Failed','err')}
}

async function loadLogs(){
  try{const d=await(await fetch('/api/logs')).json();const b=document.getElementById('log-box');b.textContent=d.logs||'(no logs)';b.scrollTop=b.scrollHeight}
  catch(e){}
}

fetchStatus(); loadLogs();
setInterval(fetchStatus,5000);
setInterval(loadLogs,15000);
</script>
</body>
</html>"""

# ── API ──────────────────────────────────────────────────────

@app.route("/")
def index():
    return Response(HTML.replace("@@PORT@@", str(PORT)), content_type="text/html")

@app.route("/api/status")
def api_status():
    return jsonify({
        "status":      service_status(),
        "service":     SERVICE_NAME,
        "bot_type":    get_bot_type(),
        "gui_enabled": gui_enabled(),
    })

@app.route("/api/service/<action>", methods=["POST"])
def api_service(action):
    if action not in ("start","stop","restart"):
        return jsonify({"ok":False,"message":"Unknown action"}), 400
    out = run(f"systemctl {action} {SERVICE_NAME}", timeout=15)
    return jsonify({"ok":True,"message":f"Service {action}ed","detail":out})

@app.route("/api/token", methods=["GET"])
def api_token_get():
    return jsonify({"token": read_token()})

@app.route("/api/token", methods=["POST"])
def api_token_set():
    data  = request.get_json(force=True)
    token = (data.get("token") or "").strip()
    if not token:
        return jsonify({"ok":False,"message":"Token empty"}), 400
    bot = get_bot_type()
    try:
        if bot == "wos-js":
            Path(f"{BOT_DIR}/src").mkdir(parents=True, exist_ok=True)
            ep = Path(JS_ENV_FILE)
            lines = [l for l in (ep.read_text().splitlines() if ep.exists() else [])
                     if not l.startswith("TOKEN=")]
            lines.insert(0, f"TOKEN={token}")
            ep.write_text("\n".join(lines) + "\n")
            os.chmod(JS_ENV_FILE, 0o640)
        else:
            Path(TOKEN_FILE).write_text(token + "\n")
            os.chmod(TOKEN_FILE, 0o640)
    except Exception as e:
        return jsonify({"ok":False,"message":str(e)}), 500
    run(f"systemctl restart {SERVICE_NAME}", timeout=10)
    return jsonify({"ok":True,"message":"Token saved and service restarted"})

@app.route("/api/switch", methods=["POST"])
def api_switch():
    data     = request.get_json(force=True)
    bot_type = data.get("bot","")
    if bot_type not in ("wos-py","wos-js","kingshot"):
        return jsonify({"ok":False,"message":"Invalid bot type"}), 400
    if switch_lock.locked():
        return jsonify({"ok":False,"message":"Switch already in progress"}), 409
    threading.Thread(target=_run_switch, args=(bot_type,), daemon=True).start()
    return jsonify({"ok":True,"message":"Switch started"})

def _run_switch(bot_type):
    with switch_lock:
        do_switch(bot_type)

@app.route("/api/switch/status")
def api_switch_status():
    return jsonify(switch_status)

@app.route("/api/gui", methods=["POST"])
def api_gui():
    data    = request.get_json(force=True)
    enabled = bool(data.get("enabled", True))
    try:
        Path("/etc/wosland").mkdir(parents=True, exist_ok=True)
        flag = Path(DESKTOP_FLAG)
        if enabled:
            flag.touch()
            run("systemctl enable lightdm 2>/dev/null; systemctl set-default graphical.target 2>/dev/null")
            msg = "Desktop enabled — takes effect on next boot"
        else:
            flag.unlink(missing_ok=True)
            run("systemctl disable lightdm 2>/dev/null; systemctl set-default multi-user.target 2>/dev/null")
            msg = "Desktop disabled — takes effect on next boot"
        return jsonify({"ok":True,"message":msg})
    except Exception as e:
        return jsonify({"ok":False,"message":str(e)}), 500

@app.route("/api/logs")
def api_logs():
    return jsonify({"logs": get_recent_logs(80)})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, debug=False)
