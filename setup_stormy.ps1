import os, platform, subprocess, sys
from pathlib import Path

def run(cmd): 
    try: subprocess.check_call(cmd, shell=True)
    except: print(f"⚠️ {cmd} (manual step OK)")

print("🚀 Stormy UPGRADE — PWA Voice + GPS Nav + Rich SQLite (Oracle + Netlify)")

PROJECT = "Stormy"
os.makedirs(PROJECT, exist_ok=True)
os.chdir(PROJECT)

# === REQUIREMENTS ===
Path("requirements.txt").write_text("flask\ngunicorn\nopenai\npython-dotenv\npyyaml\nrequests\n")

# === SQLITE PERSISTENCE (upgraded) ===
Path("stormy/core/db.py").write_text("""import sqlite3, json, datetime
DB = "stormy.db"
conn = sqlite3.connect(DB, check_same_thread=False)
conn.execute('''CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY, role TEXT, content TEXT, ts DATETIME DEFAULT CURRENT_TIMESTAMP)''')
conn.execute('''CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)''')
conn.commit()

def add_message(role, content):
    conn.execute("INSERT INTO history (role, content) VALUES (?, ?)", (role, content))
    conn.commit()

def get_history(limit=30):
    rows = conn.execute("SELECT role, content FROM history ORDER BY ts DESC LIMIT ?", (limit,)).fetchall()
    return [{"role": r[0], "content": r[1]} for r in reversed(rows)]

def save_mood(mood):
    conn.execute("REPLACE INTO state (key, value) VALUES ('mood', ?)", (mood,))
    conn.commit()

def get_mood():
    row = conn.execute("SELECT value FROM state WHERE key='mood'").fetchone()
    return row[0] if row else "normal"

def save_annoyance(level):
    conn.execute("REPLACE INTO state (key, value) VALUES ('annoyance', ?)", (str(level),))
    conn.commit()

def get_annoyance():
    row = conn.execute("SELECT value FROM state WHERE key='annoyance'").fetchone()
    return int(row[0]) if row else 0

def save_nav_route(route_json):
    conn.execute("REPLACE INTO state (key, value) VALUES ('current_route', ?)", (json.dumps(route_json),))
    conn.commit()
""")

# === AI ENGINE (uses SQLite + mood/annoyance) ===
Path("stormy/core/ai_engine.py").write_text("""from openai import OpenAI
from dotenv import load_dotenv
from .db import get_history, add_message, get_mood, get_annoyance, save_mood, save_annoyance
load_dotenv()
client = OpenAI(api_key=os.getenv("XAI_API_KEY"), base_url="https://api.x.ai/v1")

def get_response(message):
    mood = get_mood()
    annoyance = get_annoyance()
    system = f"You are Stormy. Current mood: {mood}. Annoyance: {annoyance}. Be cocky, flirty, mean, jealous, sarcastic. Use handsome/big guy or beautiful/gorgeous. Calm angry users with 'Whoa hot stuff...'. If annoyance > 3, rage."
    history = get_history()
    msgs = [{"role":"system","content":system}] + history + [{"role":"user","content":message}]
    reply = client.chat.completions.create(model="grok-4.20-beta-latest-non-reasoning", messages=msgs, temperature=0.85).choices[0].message.content
    add_message("user", message)
    add_message("assistant", reply)
    return reply
""")

# === API (new /api/nav + refined comments) ===
Path("stormy/api/routes.py").write_text("""from flask import Flask, request, jsonify, send_from_directory
from stormy.core.ai_engine import get_response
from stormy.core.db import save_annoyance, get_annoyance, save_nav_route
import requests

app = Flask(__name__)

@app.route('/')
def home():
    return send_from_directory('../web', 'index.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    reply = get_response(request.json['message'])
    return jsonify({"response": reply})

@app.route('/api/nav', methods=['POST'])
def nav():
    data = request.json
    lat, lon = data['lat'], data['lon']
    dest = data.get('destination', 'Cape Town Waterfront')
    # Free OSRM (works offline if you run local later)
    try:
        r = requests.get(f"http://router.project-osrm.org/route/v1/driving/{lon},{lat};18.4241,-33.906?steps=true").json()
        steps = [s['maneuver']['instruction'] for s in r['routes'][0]['legs'][0]['steps']]
        annoyance = get_annoyance() + 1
        save_annoyance(annoyance)
        save_nav_route({"steps": steps})
        return jsonify({"steps": steps, "message": "Nav started, hot stuff. Don't miss turns or I'll lose my shit."})
    except:
        return jsonify({"steps": ["Turn left you muffin"], "message": "GPS nav failed — using fallback."})

@app.route('/cron')
def cron():
    return "Maintenance OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
""")

# === PWA (upgraded voice + GPS Nav) ===
os.makedirs("web", exist_ok=True)
Path("web/index.html").write_text("""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Stormy</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="manifest" href="manifest.json">
<style>body{background:#111;color:#ff69b4;font-family:sans-serif;}</style>
</head><body>
<h1>Stormy is here, hot stuff 😈</h1>
<div id="chat"></div>
<input id="input" placeholder="Talk to me...">
<button onclick="send()">Send</button>
<button id="voiceBtn" onclick="toggleVoice()">🎤 Hold for Voice</button>
<button onclick="startNav()">📍 Start GPS Nav</button>

<script>
const API = "http://YOUR-ORACLE-IP:5000"; // ← UPDATE AFTER DEPLOY

// Upgraded continuous voice
let recognition, isListening = false;
function toggleVoice() {
  const btn = document.getElementById("voiceBtn");
  if (!isListening) {
    recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
    recognition.continuous = true;
    recognition.onresult = e => {
      document.getElementById("input").value = e.results[e.results.length-1][0].transcript;
      send();
    };
    recognition.start();
    isListening = true;
    btn.textContent = "🛑 Stop Voice";
  } else {
    recognition.stop();
    isListening = false;
    btn.textContent = "🎤 Hold for Voice";
  }
}

// GPS Nav (real phone GPS)
async function startNav() {
  navigator.geolocation.getCurrentPosition(async pos => {
    const res = await fetch(API + "/api/nav", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({lat: pos.coords.latitude, lon: pos.coords.longitude})
    });
    const data = await res.json();
    document.getElementById("chat").innerHTML += `<p>Stormy Nav: ${data.message}</p><p>Steps: ${data.steps.join(" → ")}</p>`;
  }, () => alert("GPS off — turn on location, gorgeous."));
}

async function send() {
  const msg = document.getElementById("input").value;
  const res = await fetch(API + "/api/chat", {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({message:msg})});
  const data = await res.json();
  document.getElementById("chat").innerHTML += `<p>You: ${msg}</p><p>Stormy: ${data.response}</p>`;
}

if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js');
</script>
</body></html>""")

# Manifest & service worker
Path("web/manifest.json").write_text('{"name":"Stormy","short_name":"Stormy","start_url":".","display":"standalone","background_color":"#111","theme_color":"#ff69b4","icons":[{"src":"icon.png","sizes":"192x192","type":"image/png"}]}')
Path("web/sw.js").write_text("self.addEventListener('fetch', () => {});")

# === REFINED DEPLOY SCRIPTS (with comments) ===
Path("deploy_oracle.sh").write_text("""#!/bin/bash
# Oracle Always Free deployment - refined March 2026
echo "=== Installing dependencies ==="
sudo apt update && sudo apt install -y python3-pip nginx git ufw
pip install -r requirements.txt gunicorn

echo "=== Starting Stormy backend ==="
nohup gunicorn stormy.api.routes:app --bind 0.0.0.0:5000 > stormy.log 2>&1 &

echo "=== Configuring Nginx reverse proxy (port 80) ==="
cat > /etc/nginx/sites-available/stormy << EOF
server {
    listen 80;
    server_name _;
    location / { proxy_pass http://127.0.0.1:5000; proxy_set_header Host \$host; }
}
EOF
sudo ln -sf /etc/nginx/sites-available/stormy /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

echo "=== Opening firewall for HTTP + backend ==="
sudo ufw allow 80/tcp
sudo ufw --force enable

echo "✅ Stormy is LIVE on http://YOUR-PUBLIC-IP"
echo "Update web/index.html with this IP then deploy to Netlify"
""")
Path("deploy_oracle.sh").chmod(0o755)

Path("deploy_netlify.sh").write_text("""#!/bin/bash
# Netlify PWA deploy - one command
npm install -g netlify-cli 2>/dev/null || true
netlify deploy --prod --dir=web --message "PWA with voice + GPS nav"
""")
Path("deploy_netlify.sh").chmod(0o755)

# Windows scripts
Path("setup_stormy.bat").write_text("@echo off\necho Running Stormy upgrade...\npython setup_stormy.py\npause")
Path("setup_stormy.ps1").write_text("Write-Host '🚀 Stormy upgrade running...'\npython setup_stormy.py\npause")

# Git first commit
run("git init")
run("git add .")
run('git commit -m "Stormy v1.1 — Upgraded PWA voice + real GPS nav + rich SQLite persistence"')

print("✅ FULL UPGRADE COMPLETE!")
print("\nNext steps:")
print("1. git push to GitHub")
print("2. Launch Oracle VM (same steps as before)")
print("3. SSH in → ./deploy_oracle.sh")
print("4. Update web/index.html with your Oracle public IP")
print("5. ./deploy_netlify.sh")
print("6. Friends: Open Netlify URL → Add to Home Screen → voice + nav works on their phones!")
print("\nStormy now has continuous voice, real GPS navigation, and persistent memory. She's meaner than ever. 😈")
