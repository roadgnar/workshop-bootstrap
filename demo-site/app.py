"""
Demo web application for workshop-bootstrap.
A minimal Flask app that serves a confirmation page and health endpoint.
"""

import os
from datetime import datetime
from flask import Flask, render_template, jsonify

app = Flask(__name__)

# Configuration
PORT = int(os.environ.get("PORT", 8080))
BUILD_TIME = os.environ.get("BUILD_TIME", "development")
VERSION = os.environ.get("VERSION", "1.0.0")


@app.route("/")
def index():
    """Serve the main confirmation page."""
    return render_template(
        "index.html",
        version=VERSION,
        build_time=BUILD_TIME,
        server_time=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        hostname=os.environ.get("HOSTNAME", "unknown"),
    )


@app.route("/health")
def health():
    """Health check endpoint for container orchestration."""
    return jsonify({
        "status": "healthy",
        "version": VERSION,
        "timestamp": datetime.now().isoformat(),
    }), 200


@app.route("/api/info")
def info():
    """Return detailed build and runtime information."""
    return jsonify({
        "version": VERSION,
        "build_time": BUILD_TIME,
        "server_time": datetime.now().isoformat(),
        "hostname": os.environ.get("HOSTNAME", "unknown"),
        "python_version": os.popen("python --version").read().strip(),
        "environment": os.environ.get("FLASK_ENV", "production"),
    })


if __name__ == "__main__":
    print(f"🚀 Starting demo server on http://0.0.0.0:{PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=os.environ.get("FLASK_ENV") == "development")

