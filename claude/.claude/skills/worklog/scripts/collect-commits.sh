#!/usr/bin/env bash
# Collects commits across all branches of the ~/Work project repos within a date range.
# Usage: collect-commits.sh <since> <until> [author]
#   <since>, <until>  anything `git log --since/--until` accepts, e.g. 2026-08-11 or "2026-08-11 23:59:59"
#   [author]          git --author pattern to filter by; "all" (or omitted) uses each repo's own
#                      configured user.name so the report defaults to "my" commits per repo.
#                      Matching by name (not email) matters: the same person can show up under
#                      different commit emails per repo (e.g. a personal address vs. a GitHub
#                      noreply address), and --author matches against the combined "Name <email>"
#                      string, so a name-based pattern catches both.
#
# Output: tab-separated  <repo>\t<YYYY-MM-DD Weekday>\t<subject>
# One line per unique commit per repo. --all already dedupes commits reachable from multiple
# branches, so this naturally covers "all branches" without double-counting.
#
# In the default ("my commits") mode, commits made by the Buglady/Ladybug coding bot are
# included too, since that work is done on the user's behalf (see BOT_AUTHORS).
#
# Merge work is dropped: besides true merge commits (--no-merges), GitHub squash/merge commits
# whose subject ends in "(#123)" are skipped, because they re-land work that already appears as
# the underlying branch commits, often days later, which would double-count it. Commits with an
# identical subject (rebased/cherry-picked copies) are collapsed to the earliest occurrence.

set -uo pipefail

SINCE="${1:?usage: collect-commits.sh <since> <until> [author]}"
UNTIL="${2:?usage: collect-commits.sh <since> <until> [author]}"
AUTHOR="${3:-}"

# Bare "YYYY-MM-DD" dates can be silently misparsed by `git log --since/--until` (observed on
# git 2.55: a plain date with no time-of-day component matches zero commits even when commits
# clearly fall in range). Appending an explicit midnight time avoids the misparse.
append_midnight() {
  local d="$1"
  if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "$d 00:00:00"
  else
    echo "$d"
  fi
}
SINCE="$(append_midnight "$SINCE")"
UNTIL="$(append_midnight "$UNTIL")"

# git's --since/--until filter on *committer* date, so rebased or squash-landed commits written
# days earlier leak into the range. Re-filter on *author* date (when the work was actually done)
# using normalized "YYYY-MM-DD HH:MM:SS" bounds, which compare correctly as strings.
SINCE_TS="$(date -d "$SINCE" '+%F %T' 2>/dev/null || echo "$SINCE")"
UNTIL_TS="$(date -d "$UNTIL" '+%F %T' 2>/dev/null || echo "$UNTIL")"

WORK_DIR="${WORK_DIR:-$HOME/Work}"

# Bot identities whose commits count as the user's own work (git --author patterns).
BOT_AUTHORS=("Ladybug Agent" "buglady-by-disruptica")

# key -> space-separated list of candidate paths (relative to WORK_DIR) to try
declare -A REPO_CANDIDATES=(
  [timetracker]="timetracker"
  [ladybug]="ladybug"
  [butterfly]="butterfly butterflyos"
  [heliflite-api]="heliflite-api heliflite/heliflite-api"
  [heliflite-plus]="heliflite-plus heliflite/heliflite-plus"
  [heliflite-ui]="heliflite-ui heliflite/heliflite-ui"
)

for key in timetracker ladybug butterfly heliflite-api heliflite-plus heliflite-ui; do
  repo=""
  for name in ${REPO_CANDIDATES[$key]}; do
    candidate="$WORK_DIR/$name"
    if [ -d "$candidate/.git" ]; then
      repo="$candidate"
      break
    fi
  done

  if [ -z "$repo" ]; then
    echo "# WARNING: no git repo found for '$key' under $WORK_DIR (tried: ${REPO_CANDIDATES[$key]})" >&2
    continue
  fi

  author_arg=()
  if [ -n "$AUTHOR" ] && [ "$AUTHOR" != "all" ]; then
    author_arg=(--author="$AUTHOR")
  elif [ -z "$AUTHOR" ]; then
    repo_name="$(git -C "$repo" config user.name 2>/dev/null || true)"
    if [ -n "$repo_name" ]; then
      author_arg=(--author="$repo_name")
    fi
    for bot in "${BOT_AUTHORS[@]}"; do
      author_arg+=(--author="$bot")
    done
  fi
  # AUTHOR == "all" -> no author filter, everyone's commits

  git -C "$repo" log --all --no-merges \
    "${author_arg[@]}" \
    --since="$SINCE" --until="$UNTIL" \
    --date=format:"%Y-%m-%d %A" \
    --pretty=tformat:"${key}%x09%ad%x09%s%x09%ai" </dev/null |
    # oldest first so dedupe keeps the earliest copy, then back to newest first
    tac |
    awk -F'\t' -v OFS='\t' -v since="$SINCE_TS" -v until="$UNTIL_TS" '
      substr($4, 1, 19) >= since && substr($4, 1, 19) < until && $3 !~ /\(#[0-9]+\)$/ && !seen[$3]++ { print $1, $2, $3 }' |
    tac
done
