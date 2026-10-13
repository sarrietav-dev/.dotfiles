#!/usr/bin/env bash
# Two simulated devices exchange logs through a local folder standing in for Drive.
set -euo pipefail
SYNC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.local/bin/pomodoro-sync"
root="$(mktemp -d)"; trap 'rm -rf "$root"' EXIT
export RCLONE_CONFIG=/dev/null POMODORO_SYNC_REMOTE="$root/drive"
mkdir -p "$root/drive"

device() { # name -> sets POMODORO_* for that device
  export POMODORO_DEVICE="$1" POMODORO_DATA_DIR="$root/$1/data" POMODORO_STATE_DIR="$root/$1/state"
  mkdir -p "$POMODORO_DATA_DIR"
}
seed() { sqlite3 "$POMODORO_DATA_DIR/pomodoro.db" "$1"; }
q() { sqlite3 "$POMODORO_DATA_DIR/pomodoro.db" "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
SCHEMA="CREATE TABLE IF NOT EXISTS sessions(id INTEGER PRIMARY KEY, task TEXT, planned_sec INTEGER, started_at INTEGER, ended_at INTEGER, status TEXT, note TEXT);
        CREATE TABLE IF NOT EXISTS parked(id INTEGER PRIMARY KEY, session_id INTEGER, text TEXT, created_at INTEGER);
        CREATE TABLE IF NOT EXISTS kv(key TEXT PRIMARY KEY, value TEXT);"

device laptop
seed "$SCHEMA INSERT INTO sessions VALUES(1,'laptop task',1500,100,1600,'completed','n');
      INSERT INTO sessions VALUES(2,'laptop running',1500,2000,NULL,'running',NULL);
      INSERT INTO kv VALUES('active','secret-timer-state');"
"$SYNC" >/dev/null
[[ -f "$root/drive/laptop.db" ]] || fail "laptop snapshot not uploaded"
[[ "$(sqlite3 "$root/drive/laptop.db" 'select count(*) from kv')" == 0 ]] || fail "timer state leaked into snapshot"

device desktop
seed "$SCHEMA INSERT INTO sessions VALUES(1,'desktop task',1500,200,1700,'completed',NULL);"
"$SYNC" >/dev/null
[[ "$(q "select task from sessions_remote where device='laptop'")" == "laptop task" ]] || fail "desktop did not import laptop session"
[[ "$(q "select count(*) from sessions_remote where device='laptop'")" == 1 ]] || fail "unfinished session was imported"
[[ "$(q "select count(*) from sessions_remote where device='desktop'")" == 0 ]] || fail "own device imported from itself"

device laptop
"$SYNC" >/dev/null
[[ "$(q "select task from sessions_remote where device='desktop'")" == "desktop task" ]] || fail "laptop did not import desktop session"

# Idempotent: a second run changes nothing and does not duplicate rows.
out="$("$SYNC")"; [[ "$out" == *"Local log unchanged"* ]] || fail "unchanged log was re-uploaded"
[[ "$(q 'select count(*) from sessions_remote')" == 1 ]] || fail "rows duplicated on re-run"

# Edits (note added later) propagate and the imported rows are replaced, not appended.
seed "UPDATE sessions SET note='updated' WHERE id=1;"
"$SYNC" >/dev/null
device desktop; "$SYNC" >/dev/null
[[ "$(q "select note from sessions_remote where device='laptop'")" == "updated" ]] || fail "update did not propagate"
[[ "$(q "select count(*) from sessions_remote")" == 1 ]] || fail "rows duplicated after update"
printf 'pomodoro-sync: all checks passed\n'
