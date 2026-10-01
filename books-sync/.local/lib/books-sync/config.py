#!/usr/bin/env python3
"""Configure Books OAuth from 1Password without printing secrets or passing them in argv."""

import configparser
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

HOME = Path.home()
CONFIG = HOME / ".config/rclone/rclone.conf"
STATE = HOME / ".local/state/books-sync"
FILTERS = HOME / ".config/books-sync/filters.txt"
REMOTE = "books-drive"
FOLDER_ID = "1MTAbND7hbreYNmH3wKCmZxggdtfduSsT"
ITEM_ID = "cbzpnxwlattw4kvp6mslnnincy"


def load_config():
    config = configparser.RawConfigParser()
    if CONFIG.exists():
        try:
            with CONFIG.open() as handle:
                config.read_file(handle)
        except configparser.Error:
            raise ValueError("Cannot read rclone configuration; no changes were made.") from None
    return config


def atomic_write(path, contents):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(contents)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def identity():
    return {
        "local": str(HOME / "Documents/Books"),
        "folder_id": FOLDER_ID,
        "filters_sha256": hashlib.sha256(FILTERS.read_bytes()).hexdigest(),
    }


def check_baseline():
    if not (STATE / "initialized").exists():
        return
    pairs = list((STATE / "bisync").glob("*.path1.lst"))
    if len(pairs) != 1 or not Path(str(pairs[0]).replace(".path1.lst", ".path2.lst")).is_file():
        raise ValueError("Sync baseline is missing or ambiguous. Restore it before running setup; automatic resync is disabled.")
    saved = STATE / "identity.json"
    if saved.exists() and json.loads(saved.read_text()) != identity():
        raise ValueError("Books paths or filters changed. Review the existing baseline before reinitializing.")


def validate(config):
    if not config.has_section(REMOTE):
        raise ValueError("Books remote is missing. Run the dotfiles Books sync installer.")
    remote = config[REMOTE]
    if remote.get("type") != "drive" or remote.get("root_folder_id") != FOLDER_ID:
        raise ValueError("Books remote does not target the expected Drive folder; sync stopped.")
    if remote.get("team_drive", "") or remote.get("scope") != "drive":
        raise ValueError("Books remote must use personal Drive with the drive scope.")
    try:
        token = json.loads(remote.get("token", "{}"))
    except json.JSONDecodeError:
        token = {}
    if not token.get("refresh_token"):
        raise ValueError("Google authorization is required. Run books-sync-authorize in a terminal.")
    check_baseline()


def configure(config):
    # An existing remote must never silently be repointed at a different collection.
    if config.has_section(REMOTE):
        remote = config[REMOTE]
        if remote.get("type") != "drive" or remote.get("root_folder_id") != FOLDER_ID:
            raise ValueError("Existing books-drive remote targets a different location; no changes were made.")
        if remote.get("team_drive", "") or remote.get("scope") != "drive":
            raise ValueError("Existing books-drive remote has incompatible scope or Shared Drive settings.")
    check_baseline()
    command = [
        "op", "item", "get", os.environ.get("BOOKS_SYNC_OP_ITEM", ITEM_ID),
        "--fields", "label=client_id,label=client_secret", "--format", "json", "--reveal",
    ]
    if os.environ.get("BOOKS_SYNC_OP_VAULT"):
        command.extend(["--vault", os.environ["BOOKS_SYNC_OP_VAULT"]])
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise ValueError("Cannot retrieve the Google Desktop client from 1Password. Unlock the app, enable CLI integration, or run op signin, then rerun setup.")
    try:
        fields = json.loads(result.stdout)
        if isinstance(fields, dict):
            fields = [fields]
        credentials = {field["label"]: field.get("value", "") for field in fields}
        client_id = credentials["client_id"]
        client_secret = credentials["client_secret"]
        if not client_id.endswith(".apps.googleusercontent.com") or not client_secret or client_secret == "concealed":
            raise ValueError
    except (KeyError, TypeError, ValueError):
        raise ValueError("1Password item must contain readable client_id and client_secret fields.") from None

    changed = not config.has_section(REMOTE)
    if changed:
        config.add_section(REMOTE)
    remote = config[REMOTE]
    # A refresh token belongs to its OAuth client; do not reuse it after rotation.
    client_changed = remote.get("client_id") != client_id or remote.get("client_secret") != client_secret
    if client_changed:
        remote.pop("token", None)
    desired = {
        "type": "drive", "client_id": client_id, "client_secret": client_secret,
        "scope": "drive", "root_folder_id": FOLDER_ID,
    }
    for key, value in desired.items():
        if remote.get(key) != value:
            remote[key] = value
            changed = True
    if changed:
        import io
        output = io.StringIO()
        config.write(output)
        atomic_write(CONFIG, output.getvalue())
    os.chmod(CONFIG, 0o600)
    try:
        token = json.loads(remote.get("token", "{}"))
    except json.JSONDecodeError:
        token = {}
    print("ready" if token.get("refresh_token") else "authorize")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"configure", "validate", "record"}:
        raise ValueError("Usage: config.py configure|validate|record")
    config = load_config()
    if sys.argv[1] == "configure":
        configure(config)
    else:
        validate(config)
        if sys.argv[1] == "record":
            if not (STATE / "initialized").is_file():
                raise ValueError("Cannot record an uninitialized baseline.")
            contents = json.dumps(identity(), indent=2) + "\n"
            path = STATE / "identity.json"
            if not path.exists() or path.read_text() != contents:
                atomic_write(path, contents)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        print(f"Books sync: {error}", file=sys.stderr)
        sys.exit(1)
