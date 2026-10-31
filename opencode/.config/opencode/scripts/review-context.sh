#!/usr/bin/env bash
# Read-only context helper for the /code-review and /security-review commands.
# Everything here runs from `!`...`` blocks, i.e. outside the agent permission flow,
# so it is deliberately strict: fixed modes, validated arguments, hardened git.
#
# Usage: review-context.sh <diff|files|log|pr-meta|pr-diff> [PR number]
set -u

MAX_BYTES=300000
UNTRACKED_MAX_BYTES=65536

# Stop repo config/attributes from running programs: pager, fsmonitor, hooks,
# external diff drivers, textconv, and index rewrites.
G=(git --no-pager --no-lazy-fetch -c core.fsmonitor=false -c core.hooksPath=/dev/null -c diff.autoRefreshIndex=false)
D=(diff --no-color --no-ext-diff --no-textconv --submodule=short)

base() {
  local r
  for r in origin/HEAD origin/main origin/master; do
    "${G[@]}" rev-parse --verify -q "$r^{commit}" && return
  done
  echo HEAD
}

cap() {
  local buf
  buf=$(head -c $((MAX_BYTES + 1)); printf x)
  buf=${buf%x}
  if ((${#buf} > MAX_BYTES)); then
    printf '%s\n[TRUNCATED at %d bytes: read the remaining files directly]\n' "${buf:0:MAX_BYTES}" "$MAX_BYTES"
  else
    printf '%s' "$buf"
  fi
}

untracked() {
  local f size
  while IFS= read -r -d '' f; do
    size=$(wc -c <"$f" 2>/dev/null || echo 0)
    if ((size > UNTRACKED_MAX_BYTES)); then
      printf 'untracked (too large, not shown): %s\n' "$f"
    elif grep -Iq . "$f" 2>/dev/null; then
      "${G[@]}" "${D[@]}" --no-index -- /dev/null "$f"
    fi
  done < <("${G[@]}" ls-files --others --exclude-standard -z)
}

pr_number() {
  if [[ ! "${1:-}" =~ ^[0-9]+$ ]]; then
    echo "invalid PR number (digits only): refusing to run gh"
    exit 0
  fi
}

case "${1:-}" in
  diff)
    { "${G[@]}" "${D[@]}" --merge-base "$(base)"; untracked; } | cap
    ;;
  files)
    "${G[@]}" diff --name-only --no-ext-diff --no-textconv --merge-base "$(base)"
    "${G[@]}" ls-files --others --exclude-standard
    ;;
  log)
    "${G[@]}" log --no-decorate --no-show-signature --oneline "$(base)..HEAD"
    ;;
  pr-meta)
    pr_number "${2:-}"
    {
      gh pr view "$2" --json title,body,state,isDraft,comments,reviews -q \
        '"\(.title)\nstate=\(.state) draft=\(.isDraft)\n\n\(.body)\n\n--- existing PR comments ---\n" + ([.comments[].body] | join("\n---\n")) + "\n\n--- existing review bodies ---\n" + ([.reviews[].body] | map(select(. != "")) | join("\n---\n"))'
      printf '\n--- existing inline review comments ---\n'
      gh api "repos/{owner}/{repo}/pulls/$2/comments" --jq '.[] | "\(.path):\(.line // .original_line) \(.body)"'
    } 2>&1 | cap
    ;;
  pr-diff)
    pr_number "${2:-}"
    gh pr diff "$2" --color=never 2>&1 | cap
    ;;
  *)
    echo "usage: review-context.sh <diff|files|log|pr-meta|pr-diff> [PR number]" >&2
    exit 2
    ;;
esac
