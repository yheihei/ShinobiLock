#!/usr/bin/env python3
"""Read this debug app's evidence and print a token-redacted report."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def timestamp(value):
    if value is None:
        return None
    return datetime.fromtimestamp(value + 978307200, timezone.utc).astimezone().isoformat(timespec="seconds")


def token_id(token):
    if token is None:
        return None
    encoded = json.dumps(token, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()[:10]


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--device", required=True)
parser.add_argument("--bundle-id", required=True)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
environment = dict(os.environ)
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
with tempfile.TemporaryDirectory(prefix="shinobilock-probe-") as temp:
    raw = Path(temp) / "evidence.json"
    result = subprocess.run([
        "xcrun", "devicectl", "device", "copy", "from", "--device", args.device,
        "--domain-type", "appDataContainer", "--domain-identifier", args.bundle_id,
        "--source", "Documents/probe-evidence.json", "--destination", str(raw),
        "--timeout", "20", "--quiet",
    ], env=environment)
    if result.returncode:
        parser.exit(1, "検証ログを取得できませんでした。接続先とBundle IDを確認し、iPhoneでDebug版のカルマロックを開いてから再実行してください。\n")
    state = json.loads(raw.read_text())

access = state.get("temporaryAccess")
pending = state.get("pendingUnlockRequest")
report = {
    "rules": [{
        "id": rule["id"], "name": rule["name"],
        "schedule": rule["schedule"], "isEnabled": rule["isEnabled"],
        "applications": [token_id(token) for token in rule.get("applications", [])],
    } for rule in state.get("rules", [])],
    "lockedApplications": [token_id(token) for token in state.get("lockedApplications", [])],
    "pendingApplication": token_id(pending["token"] if pending else state.get("pendingApplication")),
    "pendingUnlockRequest": None if not pending else {
        "id": pending["id"],
        "application": token_id(pending["token"]),
        "requestedAt": timestamp(pending["requestedAt"]),
    },
    "temporaryAccess": None if not access else {
        "application": token_id(access["token"]),
        "startedAt": timestamp(access["window"]["startedAt"]),
        "deadline": timestamp(access["window"]["startedAt"] + 300),
    },
    "events": [{
        "id": event["id"], "at": timestamp(event["timestamp"]),
        "kind": event["kind"], "application": token_id(event.get("application")),
        "note": event.get("note"),
    } for event in state.get("events", [])],
}
formatted = json.dumps(report, ensure_ascii=False, indent=2)
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(formatted + "\n")
print(formatted)
