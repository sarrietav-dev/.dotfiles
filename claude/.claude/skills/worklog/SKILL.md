---
name: worklog
description: >
  Summarize what was actually worked on across the ~/Work project repos — timetracker,
  ladybug, butterflyos, and the three heliflite-* repos (heliflite-api, heliflite-plus,
  heliflite-ui) — for a timeframe the user names (today, yesterday, this week, last week,
  since Monday, a date range, a month, etc). Scans every branch (local and remote) in each
  repo, not just the checked-out one, and turns the commits into a plain-language work log
  for non-technical readers (e.g. a client update or a timesheet note) — never raw commit
  messages. Use whenever the user asks what they worked on, wants a recap/summary/report of
  recent work, a timesheet narrative, or asks things like "what did I do this week",
  "summarize yesterday's work", or "what happened on heliflite last month".
allowed-tools: Bash(git:*), Bash(date:*), Bash(~/.claude/skills/worklog/scripts/collect-commits.sh:*), Read
---

# Worklog

Turn git history across the `~/Work` projects into a plain-language work log.

## Projects

| key | directory | notes |
|---|---|---|
| timetracker | `~/Work/timetracker` | |
| ladybug | `~/Work/ladybug` | |
| butterfly | `~/Work/butterflyos` | on-disk folder is `butterflyos`, not `butterfly` |
| heliflite-api | `~/Work/heliflite/heliflite-api` | lives under the `heliflite/` parent folder |
| heliflite-plus | `~/Work/heliflite/heliflite-plus` | lives under the `heliflite/` parent folder |
| heliflite-ui | `~/Work/heliflite/heliflite-ui` | lives under the `heliflite/` parent folder |

The collection script already knows about the `butterflyos` naming quirk and the `heliflite/`
parent folder. If a repo has moved or been renamed again, it prints a `# WARNING` line to
stderr instead of failing the other repos.

## Step 1 — resolve the timeframe to concrete dates

Do this yourself before calling the script — don't rely on git's fuzzy date parsing for
calendar-boundary phrases like "this week", since it doesn't align to calendar weeks/months.
Use the `date` command relative to **today** (check the current date already in context, or
run `date +%F` if unsure) to compute an explicit `SINCE`/`UNTIL`. `UNTIL` should be exclusive
end-of-range in `YYYY-MM-DD` form (git treats `--until=<date>` as that date's midnight, i.e.
up to but not including it), or add ` 23:59:59` to make a specific end day inclusive.

Watch out for a GNU `date` gotcha: a bare weekday name like `date -d 'monday'` means the
**next** occurrence of that day (strictly in the future), not the current week's. Always use
`date -d 'last monday'` instead — that correctly means "the most recent Monday, including
today if today is Monday," which is what "this week" / "since Monday" actually mean. Verify
with `date -d 'last monday' +%F` before trusting it if you're unsure.

Examples (assuming today is 2026-08-18, a Tuesday):
- "today" → SINCE=2026-08-18, UNTIL=2026-08-19
- "yesterday" → SINCE=2026-08-17, UNTIL=2026-08-18
- "this week" (Mon–today) → SINCE=$(date -d 'last monday' +%F) → 2026-08-17, UNTIL=2026-08-19
- "last week" → SINCE=$(date -d 'last monday -7 days' +%F) → 2026-08-10, UNTIL=$(date -d 'last monday' +%F) → 2026-08-17
- "since Monday" → SINCE=$(date -d 'last monday' +%F), UNTIL=tomorrow
- "last 3 days" → SINCE=$(date -d '3 days ago' +%F), UNTIL=tomorrow
- "August" / "last month" → SINCE=first of that month, UNTIL=first of the following month
- explicit range "Aug 1 to Aug 15" → SINCE=2026-08-01, UNTIL=2026-08-16

When ambiguous, ask the user rather than guessing (e.g. "this week" starting Sunday vs Monday).

## Step 2 — collect commits

Run the bundled script once per invocation. It already loops over all six repos and all their
branches (`git log --all`, deduped). It also drops merge work: true merge commits, and GitHub
squash/merge commits whose subject ends in `(#123)`. Those re-land work that already shows up
as the underlying branch commits, often days later, so counting them would log the same work
twice. Rebased or cherry-picked copies with an identical subject collapse to the earliest one,
and commits are placed on their *author* date (when the work was done), not the date they were
merged:

```
~/.claude/skills/worklog/scripts/collect-commits.sh "<SINCE>" "<UNTIL>" [AUTHOR]
```

- Omit `AUTHOR` (or pass nothing) to default to **the user's own commits**, using each repo's
  own configured `git config user.name` — this is almost always what "what did I do" means.
  This default also includes commits by the Buglady coding bot (`Ladybug Agent` and
  `buglady-by-disruptica[bot]`; see `BOT_AUTHORS` in the script), since that work is done on the
  user's behalf.
- Pass `AUTHOR=all` to include everyone's commits (e.g. "what happened on the team this week").
- Pass a specific name/email substring to filter to one other person.

Output is tab-separated: `repo<TAB>YYYY-MM-DD Weekday<TAB>commit subject`. One line per unique
commit. If the script warns about a missing repo on stderr, mention that to the user instead
of silently dropping that project from the report.

If you suspect remote branches are stale (new work pushed elsewhere, not yet fetched locally),
you may run `git -C ~/Work/<dir> fetch --all --quiet` first for each repo — this is safe and
read-only from the report's perspective, but do mention you did it since it touches network.

## Step 3 — synthesize the plain-language log

This is the part that needs judgment, not a script. Default to **granular**: one row per
distinct piece of work, not one blended row per (date, project). Group the raw commit lines by
date and project, then within that group cluster commits that are really the same underlying
task (e.g. a fix commit and its immediate follow-up fix-of-the-fix, or a feature commit split
across "add backend" + "add frontend for it") into a single row — but do not fold genuinely
separate tasks together just because they landed the same day in the same project. When in
doubt, split rather than combine. Rewrite each row's commit(s) into one plain-English
description a non-technical stakeholder (e.g. a client, or future-you skimming a timesheet)
would understand — describe the *outcome*, not the mechanism:

- Translate jargon: "fix ticket page crash when reply has no linked user" → "fixed a bug where
  the support ticket page could crash"; "add MCP tools for accounts, SOWs..." → "connected the
  billing and account data so it can be queried automatically".
- Routine dependency-bump/chore commits are noise — omit them unless they're the only activity
  that project had that day, in which case summarize as routine maintenance in a single row.
- Buglady bot commits pack the title and part of the body into one subject line, truncated with
  `…` (e.g. "Lobby page may show staff their own internal comments On the public lob…"). Read
  the part before the body as the task. A bot commit often covers the same task as one of the
  user's own fix commits a day either side (the user fixes it and the bot's branch lands it too,
  or the other way round). Treat those as one row, on the earliest date, rather than two.
- Keep each description under 255 characters.
- Skip (date, project) pairs with zero qualifying commits — don't emit empty rows for them.

## Step 4 — output format

A markdown table, one row per (day, project), most recent day first (or chronological if the
user asks for a narrative), with columns in this order:

```
| Day | Project | What was done |
|---|---|---|
```

- **Day**: `Weekday, Month Day` (e.g. `Friday, August 14`)
- **Project**: `Timetracker`, `Ladybug`, `ButterflyOS`, `Heliflite API`, `Heliflite Plus`, or `Heliflite UI`
- **What was done**: the plain-language description, under 255 characters

Example:

```
| Day | Project | What was done |
|---|---|---|
| Friday, August 14 | Timetracker | Fixed a bug where the support ticket page crashed on certain replies, and cleaned up how the help-desk inbox routes incoming email. |
| Friday, August 14 | Ladybug | Added a deploy checklist to make releases safer. |
| Wednesday, August 5 | Timetracker | Connected billing, timesheets, and account data so they can be pulled automatically instead of by hand. |
| Tuesday, July 28 | ButterflyOS | Added the ability to log in automatically to check timesheets and billing status. |
```

After the table, add one line stating that Ladybug-bot (Buglady / "Ladybug Agent") commits are
included by default, and name which rows (if any) were mostly or partly bot-authored, e.g.
"Includes Ladybug bot work in the Ladybug rows." Say so even when no bot commits appeared that
period ("no bot commits in this range"), so the reader never has to guess. If the user passed an
explicit AUTHOR filter, say bot commits were excluded instead.

Do not include commit hashes, branch names, file paths, or other technical detail in the final
output — that belongs in the raw data you gathered in Step 2, not in what you show the user.
