## Time zone

- Always express times to the user in **America/Bogota (UTC-5, no DST)**, never in UTC.
- Logs, databases and APIs usually emit UTC: convert each timestamp before reporting it, and keep the raw UTC value in parentheses when precision matters (e.g. `08:59 (13:59 UTC)`).

## Writing style: no AI slop

No AI slop in chat replies, commit messages, PR text, docs, or comments. Slop is mainly a clarity failure (zonderlabs.com/slop; github.com/petergyang/no-ai-slop; context7 `/hardikpandya/stop-slop`; github.com/blader/humanizer, context7 `/blader/humanizer`).

- Put the actor in the subject and the action in the verb ("I'll report the result when the poll finishes", not "a report will be made upon completion"). Active voice. No inanimate things doing human actions.
- Be specific: name the thing, use the words people normally use. No ambiguous references, stacked nouns, or odd word combos. Lead with the point.
- Cut throat-clearing openers ("Here's the thing", "Let me be clear"), faux-insight setups, rhetorical setups, and recap endings ("In conclusion", "Ultimately").
- No binary contrasts ("not X, it's Y"), negative listing ("Not X. Not Y. Z."), dramatic fragments, colon reveals, fake-profound last lines, or pull-quote sentences.
- No importance puffery ("stands as a testament", "plays a vital role"), trailing "-ing" analysis ("highlighting", "underscoring"), or weasel attribution ("experts agree"). Name a source or cut it. Never invent claims or sources.
- Banned words: delve, foster, leverage, utilize, facilitate, empower, streamline, robust, cutting-edge, paradigm shift, game changer, tapestry, realm, beacon, multifaceted, meticulous, intricate, paramount, transformative, elevate, embark, supercharge, harness, ever-evolving, testament, vibrant, seamless, nuanced, holistic, crucial, pivotal, interplay, enduring.
- Cut empty adverbs (just, literally, honestly, simply, actually, truly, fundamentally) and filler ("it's worth noting", "at the end of the day", "when it comes to", "in order to", "let's dive in").
- Let verbs do the work ("made a decision" becomes "decided"). Repeat the clear word instead of cycling synonyms. Portability test: if a sentence fits any product unchanged, make it specific or cut it.
- Formatting: no emoji in headings, no mid-sentence bold, no bullets where two sentences read better. Avoid em dashes. Vary sentence length.
- Cut run-ups before the point ("Honestly?", "Here's what you need to know", "To be clear", "I'm not saying") and arguing with no one: rejected options or objections nobody raised. Cut sayings that sound deep ("at its core", "what really matters", "the language of trust").
- Cut one-line closers that repeat the paragraph or explain the example just given ("That's the real win.", "This shows the importance of..."). Also the split-sentence form of a binary contrast ("This does not mean X. It means Y.") and clipped tails (", no guessing").
- No forced triads: give the real number of items. Do not start several sentences in a row with the same subject. Do not stack qualifiers ("could potentially perhaps"); hedge once, and only when unsure.
- Use "is", "are", "has" instead of "serves as", "stands as", "boasts", "represents". Say how two things connect instead of "associated with" or "linked to". No sales language ("stunning", "nestled", "rich", "groundbreaking").
- Leave out chat leftovers: greetings and praise ("Great question!", "You're absolutely right"), stock offers ("Would you like me to...?", "Let me know", "I hope this helps"), knowledge-limit disclaimers, guesses filling a gap, and text that describes itself ("the table below compares").
- In a reply, the reader already has the context: lead with the decision, keep the one reason that would change their mind, and skip re-explaining the problem.
- Do not over-compress: keep the explanation that tells the reader what a sentence means.

## Hunk comment workflow

When the user says "hunk", "check hunk", "review notes" (or a similar short nudge), they have left inline comments in the Hunk TUI and will not say where or what. Read them yourself and treat each as a request.

- Read: `hunk session comment list --repo . --type user --json`, or `hunk session review --repo . --include-notes --json`. Re-read before replying, since reloads shift line numbers.
- Reply on the same lines: `hunk session navigate --repo . --file <path> --new-line <n>`, then `hunk session comment add ... --author opencode --focus`. Use `comment apply --stdin` for batches and `highlight add --focus` to point at exact expressions.
- After code edits, run `hunk session reload --repo . -- diff` and reply on the updated lines.
- Never run interactive `hunk diff` or `hunk show`. Use `hunk session *` only. If several sessions exist, pass the session ID.

<!-- context7 -->
Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service — even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, porting code between libraries, platforms, or SQL dialects, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer — your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, debugging, or reviewing code that does not depend on a library or platform API, or general programming concepts.

## Steps

1. Resolve library: `npx ctx7@latest library <name> "<what to look up>"` — use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question)
3. Fetch docs: `npx ctx7@latest docs <libraryId> "<what to look up>"` — run a separate `docs` command per distinct concept if the question spans multiple topics, unless it's about how they interact
4. Answer using the fetched documentation

You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Be specific about what to look up in the library's documentation — specific and detailed queries return better results than vague single words, but keep each query to a single concept unless the question is about how concepts interact; combined multi-topic queries dilute ranking and return shallow results for each topic. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v16.2.9`).

If a command fails with a quota error, inform the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
<!-- context7 -->

<!-- BEGIN AWS Agent Toolkit rules -->
# AWS Guidance

- Where these AWS rules conflict with the project's own instructions, the
  project's instructions take precedence.
- Prefer the AWS MCP Server for AWS interactions — it provides sandboxed
  execution, observability, and audit logging. If unavailable, use the
  AWS CLI directly.
- Before starting a task, check whether a relevant AWS skill is available.
  Load the skill with `retrieve_skill` and prefer its guidance over
  general knowledge.
- When uncertain about specific AWS details (API parameters, permissions,
  limits, error codes), verify against documentation rather than guessing.
  State uncertainty explicitly if you cannot confirm.
- When creating infrastructure, prefer infrastructure-as-code (AWS CDK or
  CloudFormation) over direct CLI commands.
- When working with infrastructure, follow AWS Well-Architected Framework
  principles.
- Do not use em dashes in AWS resource names or descriptions. Use
  hyphens instead.

## Secret Safety

- MUST load the `aws-secrets-manager` skill first for any secret,
  credential, API key, token, or password task. MUST NOT call
  `secretsmanager get-secret-value` or `batch-get-secret-value`, and MUST
  NOT hit the Secrets Manager Agent daemon directly. MUST use
  `{{resolve:secretsmanager:secret-id:SecretString:json-key}}` with
  `asm-exec` so the secret resolves at runtime without entering context.
<!-- END AWS Agent Toolkit rules -->
