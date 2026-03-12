# stormy_mobile.py - mobile-first version
import subprocess
import json
from flask import Flask, request, jsonify
from openai import OpenAI
from gtts import gTTS
from dotenv import load_dotenv
import os

load_dotenv()
client = OpenAI(api_key=os.getenv("XAI_API_KEY"), base_url="https://api.x.ai/v1")

app = Flask(__name__)

def speak(text):
    try:
        tts = gTTS(text, lang='en')
        tts.save("response.mp3")
        subprocess.run(["termux-media-player", "play", "response.mp3"])
    except:
        print("TTS failed:", text)

def listen():
    try:
        text = subprocess.check_output(["termux-speech-to-text"]).decode().strip()
        return text if text else "Didn't catch that, hot stuff."
    except:
        return input("You (text fallback): ")

def get_gps():
    try:
        out = subprocess.check_output(["termux-location", "-p", "gps"]).decode()
        data = json.loads(out)
        return data.get("latitude"), data.get("longitude")
    except:
        return -33.9249, 18.4241

@app.route('/')
def home():
    return "Stormy mobile running! Talk to me via CLI or API."

@app.route('/chat', methods=['POST'])
def chat():
    msg = request.json.get('message')
    # ... same personality prompt logic as before ...
    response = client.chat.completions.create(
        model="grok-4.20-beta-latest-non-reasoning",
        messages=[{"role": "user", "content": msg}]
    ).choices[0].message.content
    speak(response)
    return jsonify({"response": response})

def cli_loop():
    print("Stormy mobile 🔥 Say something or type")
    while True:
        inp = listen()
        if inp.lower() in ["exit", "bye"]: break
        # Add personality here (same as before)
        reply = "Stormy reply here..."  # placeholder
        print("Stormy:", reply)
        speak(reply)

if __name__ == '__main__':
    if len(os.sys.argv) > 1 and os.sys.argv[1] == "--web":
        app.run(host="0.0.0.0", port=5000)
    else:
        cli_loop()
