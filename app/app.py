import os

from flask import Flask, jsonify

app = Flask(__name__)

# Placeholder for a value that will be sourced from AWS Secrets Manager in
# Phase 5. Falls back to a default so the app runs standalone with no setup.
APP_SECRET_MESSAGE = os.environ.get(
    "APP_SECRET_MESSAGE", "default-message-not-from-secrets-manager-yet"
)


@app.route("/")
def index():
    return jsonify(status="ok", service="secure-cloud-pipeline")


@app.route("/health")
def health():
    return jsonify(status="healthy")


@app.route("/config")
def config():
    return jsonify(message=APP_SECRET_MESSAGE)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
