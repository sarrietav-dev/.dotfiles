# Hunk comment workflow

When the user says "hunk", "check hunk", "review notes" (or a similar short nudge), they have left inline comments in the Hunk TUI and will not say where or what. Read them yourself and treat each as a request.

- Read: `hunk session comment list --repo . --type user --json`, or `hunk session review --repo . --include-notes --json`. Re-read before replying, since reloads shift line numbers.
- Reply on the same lines: `hunk session navigate --repo . --file <path> --new-line <n>`, then `hunk session comment add ... --author claude --focus`. Use `comment apply --stdin` for batches and `highlight add --focus` to point at exact expressions.
- After code edits, run `hunk session reload --repo . -- diff` and reply on the updated lines.
- Never run interactive `hunk diff` or `hunk show`. Use `hunk session *` only. If several sessions exist, pass the session ID.
- For passive polling the user can run `/loop 1m check hunk for new user comments and respond`.
