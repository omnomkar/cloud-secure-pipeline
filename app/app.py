import os

import boto3
from flask import Flask, jsonify

app = Flask(__name__)


def _load_app_secret_message():
    secret_name = os.environ.get("SECRETS_MANAGER_SECRET_NAME")
    if secret_name:
        # Fetched once at import time, not per-request - the value doesn't
        # change without a redeploy, and Secrets Manager bills per API call.
        # SECRETS_MANAGER_SECRET_NAME being set means we're explicitly
        # expecting this to work, so a failure here is allowed to raise and
        # crash startup rather than falling back to the placeholder - a
        # silent fallback would hide a real IAM or network problem.
        # Explicit region rather than relying on boto3's autodetection -
        # autodetection depends on IMDS being reachable with the right hop
        # limit (it is, see live/k3s_instance.tf), but failing loudly on a
        # missing AWS_REGION is more obvious than a region-resolution bug
        # surfacing as a generic connection error.
        client = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION"))
        return client.get_secret_value(SecretId=secret_name)["SecretString"]

    # No SECRETS_MANAGER_SECRET_NAME set - same standalone behavior as
    # Phase 2, zero AWS access required for local runs.
    return os.environ.get(
        "APP_SECRET_MESSAGE", "default-message-not-from-secrets-manager-yet"
    )


APP_SECRET_MESSAGE = _load_app_secret_message()


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
