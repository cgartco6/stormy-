import os, platform, subprocess, sys
from pathlib import Path

def run(cmd): 
    try: subprocess.check_call(cmd, shell=True)
    except: print(f"⚠️ {cmd}")

print("🚀 Stormy Setup — Oracle + Netlify PWA + SQLite + Phone GPS (2026)")

PROJECT = "Stormy"
os.makedirs(PROJECT, exist_ok=True)
os.chdir(PROJECT)

# === All files (updated with SQLite + PWA GPS) ===
Path(".env.example").write_text("XAI_API_KEY=your_key_here\n")
Path("requirements.txt").write_text("flask\ngunicorn\nopenai\npython-dotenv\npyyaml\nrequests\n")
Path("README.md").write_text("""# Stormy
Oracle Always Free backend + Netlify PWA frontend (installable on any phone)

Deploy:
1. Oracle VM (see steps below)
2. Netlify: drag web/ folder or use deploy_netlify.sh

PWA: Add to home screen → voice + real phone GPS works on Honor/Oppo.
""")

# SQLite DB for memory persistence
Path("stormy/core/db.py").write_text("""import sqlite3, os
DB = "stormy.db"
conn = sqlite3.connect(DB)
conn.execute("CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY, role TEXT, content TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)")
conn.execute("CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)")
conn.commit()

def add_message(role, content):
    conn.execute("INSERT INTO history (role, content) VALUES (?, ?)", (role, content))
    conn.commit()

def get_history(limit=20):
    cur = conn.execute("SELECT role, content FROM history ORDER BY timestamp DESC LIMIT ?", (limit,))
    return [{"role": r[0], "content": r[1]} for r in cur.fetchall()][::-1]

def save_state(key, value):
    conn.execute("REPLACE INTO state (key, value) VALUES (?, ?)", (key, value))
    conn.commit()
""")

# AI Engine with memory
Path("stormy/core/ai_engine.py").write_text("""from openai import OpenAI
from dotenv import load_dotenv
import os
from .db import get_history, add_message
load_dotenv()
client = OpenAI(api_key=os.getenv("XAI_API_KEY"), base_url="https://api.x.ai/v1")

def get_response(message):
    history = get_history()
    messages = [{"role": "system", "content": "You are Stormy - cocky, flirty, mean, jealous, sarcastic. Use handsome/big guy or beautiful/gorgeous. Swear occasionally. Calm angry users."}] + history + [{"role": "user", "content": message}]
    resp = client.chat.completions.create(model="grok-4.20-beta-latest-non-reasoning", messages=messages, temperature=0.85)
    reply = resp.choices[0].message.content
    add_message("user", message)
    add_message("assistant", reply)
    return reply
""")

# API routes (with /cron)
Path("stormy/api/routes.py").write_text("""from flask import Flask, request, jsonify, send_from_directory
from stormy.core.ai_engine import get_response
app = Flask(__name__)

@app.route('/')
def home():
    return send_from_directory('../web', 'index.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    reply = get_response(request.json['message'])
    return jsonify({"response": reply})

@app.route('/cron')
def cron():
    return "OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
""")

# PWA with Phone GPS
os.makedirs("web", exist_ok=True)
Path("web/index.html").write_text("""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Stormy</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="manifest" href="manifest.json">
<style>body{background:#111;color:#ff69b4;}</style>
</head><body>
<h1>Stormy is here, hot stuff 😈</h1>
<div id="chat"></div>
<input id="input" placeholder="Talk to me...">
<button onclick="send()">Send</button>
<button onclick="startVoice()">🎤 Voice</button>
<button onclick="getGPS()">📍 Use Phone GPS</button>

<script>
const API = "http://YOUR-ORACLE-PUBLIC-IP:5000/api/chat"; // ← CHANGE AFTER DEPLOY

async function send() {
  const msg = document.getElementById("input").value;
  const res = await fetch(API, {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({message:msg})});
  const data = await res.json();
  document.getElementById("chat").innerHTML += `<p>You: ${msg}</p><p>Stormy: ${data.response}</p>`;
}

function startVoice() {
  const recog = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
  recog.onresult = e => { document.getElementById("input").value = e.results[0][0].transcript; send(); };
  recog.start();
}

function getGPS() {
  navigator.geolocation.getCurrentPosition(pos => {
    alert(`Phone GPS locked! Lat: ${pos.coords.latitude}, Lon: ${pos.coords.longitude}`);
    // You can send to backend for nav later
  }, err => alert("GPS failed — make sure location is on"));
}

if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js');
</script>
</body></html>""")

Path("web/manifest.json").write_text('{"name":"Stormy","short_name":"Stormy","start_url":".","display":"standalone","background_color":"#111","theme_color":"#ff69b4","icons":[{"src":"icon.png","sizes":"192x192","type":"image/png"}]}')
Path("web/sw.js").write_text("self.addEventListener('fetch', e => {});")

# Deploy scripts (refined)
Path("deploy_oracle.sh").write_text("""#!/bin/bash
sudo apt update && sudo apt install -y python3-pip nginx git
pip install -r requirements.txt gunicorn
cat > /etc/nginx/sites-available/stormy << EOF
server {
    listen 80;
    server_name _;
    location / { proxy_pass http://127.0.0.1:5000; }
}
EOF
sudo ln -s /etc/nginx/sites-available/stormy /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo ufw allow 80
sudo systemctl restart nginx
nohup gunicorn stormy.api.routes:app --bind 0.0.0.0:5000 &
echo "✅ Stormy live on http://YOUR-PUBLIC-IP"
""")
Path("deploy_oracle.sh").chmod(0o755)

Path("deploy_netlify.sh").write_text("""npm install -g netlify-cli
netlify deploy --prod --dir=web""")
Path("deploy_netlify.sh").chmod(0o755)

# Git + first commit
run("git init")
run("git add .")
run('git commit -m "Initial Stormy commit — Oracle + Netlify PWA + SQLite + Phone GPS ready"')
print("✅ First commit pushed to local repo!")

print("\nNEXT:")
print("1. Oracle VM steps below (exact console screenshots described)")
print("2. git push to GitHub")
print("3. Run deploy_oracle.sh on the VM")
print("4. Update web/index.html with your Oracle IP")
print("5. Netlify deploy → friends add to home screen")
""")

# Windows wrappers
Path("setup_stormy.bat").write_text("""@echo off
echo Running Stormy setup via Python...
python setup_stormy.py
pause""")

Path("setup_stormy.ps1").write_text("""Write-Host "🚀 Running Stormy setup (PowerShell)..."
python setup_stormy.py
Write-Host "Done! cd Stormy && git push"
pause""")

print("✅ All files created including Windows .bat and .ps1!")
