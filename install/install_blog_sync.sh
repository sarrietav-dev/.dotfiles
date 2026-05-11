#!/usr/bin/env bash
set -euo pipefail

# Blog sync: watch ~/Documents/Writing/blog/, auto-sync to site repo _posts/
# Does NOT assume gh auth, git remote, or that repo exists
# Safe to run multiple times (idempotent)

SITE_REPO="${1:-$HOME/Work/site}"
BLOG_DIR="$HOME/Documents/Writing/blog"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "📝 Setting up blog auto-sync..."
echo "   Blog source: $BLOG_DIR"
echo "   Site repo: $SITE_REPO"
echo ""

# Create blog directory (idempotent)
mkdir -p "$BLOG_DIR"

# Create site repo if it doesn't exist (warning only, script will handle it)
if [[ ! -d "$SITE_REPO/.git" ]]; then
  echo "⚠️  Site repo not found at $SITE_REPO"
  echo "   The sync script will still work, but git push will fail until you clone/create it."
  echo "   The commit will remain local."
  echo ""
else
  echo "✓ Found site repo at $SITE_REPO"
fi

# Create sync script (idempotent — overwrites if exists)
if [[ ! -d "$SITE_REPO" ]]; then
  mkdir -p "$SITE_REPO"
fi

cat > "$SITE_REPO/translate-post.sh" << 'TRANSLATE_EOF'
#!/usr/bin/env bash
set -euo pipefail

EN_POST="$1"
POSTS_DIR="$(dirname "$EN_POST")"

# Extract frontmatter fields
title=$(sed -n 's/^title: //p' "$EN_POST" | head -1)
date=$(sed -n 's/^date: //p' "$EN_POST" | head -1 | grep -oP '^\d{4}-\d{2}-\d{2}')
description=$(sed -n 's/^description: //p' "$EN_POST" | head -1)
translation_key=$(sed -n 's/^translation_key: //p' "$EN_POST" | head -1)

# Generate translation_key from filename if not set
if [[ -z "$translation_key" ]]; then
  basename=$(basename "$EN_POST" .md)
  translation_key="${basename#????-??-??-}"  # strip YYYY-MM-DD- prefix
fi

# Skip if Spanish version already exists
if grep -rl "translation_key: $translation_key" "$POSTS_DIR" 2>/dev/null | xargs grep -l "^lang: es" 2>/dev/null | grep -q . 2>/dev/null; then
  echo "blog: Spanish translation already exists for $translation_key"
  exit 0
fi

# Add lang: en and translation_key to English post if missing (using awk to preserve structure)
if ! grep -q "^lang:" "$EN_POST"; then
  awk '/^---$/{if(++count==2){print "lang: en"; print "translation_key: '$translation_key'"}} 1' "$EN_POST" > "$EN_POST.tmp" && mv "$EN_POST.tmp" "$EN_POST"
elif ! grep -q "^translation_key:" "$EN_POST"; then
  sed -i "/^lang: en/a translation_key: $translation_key" "$EN_POST"
fi

# Translate using Claude CLI, fallback to opencode
PROMPT="Translate this Jekyll blog post to Spanish. Return ONLY the complete translated post (frontmatter + body), nothing else.

Rules:
- Translate title, description, and body text to Spanish
- Keep date, translation_key, and all other non-text fields unchanged
- Set lang: es
- Add a permalink field: /es/blog/<spanish-slug>/ where the slug is the translated title in kebab-case
- Do NOT include \`\`\`yaml or \`\`\`markdown fences — return raw markdown

Post to translate:
$(cat "$EN_POST")"

translated=$(claude -p "$PROMPT" 2>/dev/null || true)

# Fallback to opencode if claude failed
if [[ -z "$translated" ]]; then
  echo "blog: claude failed, trying opencode..." >&2
  translated=$(opencode run "$PROMPT" 2>/dev/null || true)
fi

if [[ -z "$translated" ]]; then
  echo "⚠️  Translation failed — both claude and opencode returned empty output" >&2
  exit 1
fi

# Extract Spanish slug from the permalink line
es_slug=$(echo "$translated" | grep "^permalink:" | sed 's|.*/es/blog/||;s|/$||' | head -1)
if [[ -z "$es_slug" ]]; then
  es_slug="es-$(basename "$EN_POST" .md)"
fi

# Write Spanish post (remove spanish: true flag if it appears)
es_filename="${date}-${es_slug}.md"
es_post="$POSTS_DIR/$es_filename"
echo "$translated" | sed '/^spanish: true/d' > "$es_post"

echo "blog: created Spanish post → $es_filename" >&2
TRANSLATE_EOF
chmod +x "$SITE_REPO/translate-post.sh"
echo "✓ Created/updated translate script at $SITE_REPO/translate-post.sh"

cat > "$SITE_REPO/sync-from-blog.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

SITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_SRC="$HOME/Documents/Writing/blog/"
POSTS_DST="$SITE_ROOT/_posts/"

# Calculate the proper kebab-case name with date prefix
get_proper_name() {
  local src="$1"
  local basename="${src##*/}"
  local name_only="${basename%.*}"
  local ext="${basename##*.}"

  # Extract date from frontmatter or use file mtime
  local date
  if [[ -f "$src" ]]; then
    date=$(sed -n '/^date: /p' "$src" | head -1 | sed 's/^date: *\([0-9\-]*\).*/\1/')
    if [[ -z "$date" ]]; then
      date=$(date -d "@$(stat -c %Y "$src")" +%Y-%m-%d)
    fi
  else
    return 0
  fi

  # Convert to kebab-case: lowercase, replace spaces/underscores with hyphens
  name_only=$(echo "$name_only" | tr '[:upper:]' '[:lower:]' | sed 's/[_[:space:]]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g')

  # Remove existing date prefix if present
  name_only=$(echo "$name_only" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')

  echo "$date-$name_only.$ext"
}

# Rename file in-place if it doesn't have the correct format
rename_in_place() {
  local src="$1"
  local basename="${src##*/}"
  local proper_name=$(get_proper_name "$src")

  if [[ "$basename" != "$proper_name" ]]; then
    local dir="${src%/*}"
    local new_path="$dir/$proper_name"
    mv "$src" "$new_path"
    echo "$new_path"
  else
    echo "$src"
  fi
}

mkdir -p "$BLOG_SRC" "$POSTS_DST"

# Track which posts exist in source (by new name)
declare -A synced_posts

# Rename files in blog dir and sync to posts
for post in "$BLOG_SRC"/*.md; do
  [[ -e "$post" ]] || continue

  # Rename in-place if needed
  post=$(rename_in_place "$post")

  # Copy to posts dir
  new_name=$(basename "$post")
  cp "$post" "$POSTS_DST/$new_name"
  synced_posts["$new_name"]=1

  # Check for spanish: true flag and translate if present
  if grep -q "^spanish: true" "$POSTS_DST/$new_name" 2>/dev/null; then
    "$SITE_ROOT/translate-post.sh" "$POSTS_DST/$new_name" 2>&1 || true
    # Remove spanish: true flag from source and posts (translation handled)
    sed -i '/^spanish: true/d' "$post"
    sed -i '/^spanish: true/d' "$POSTS_DST/$new_name"
  fi
done

# Remove posts that no longer exist in source (but skip Spanish posts — they're generated)
for post in "$POSTS_DST"/*.md; do
  [[ -e "$post" ]] || continue
  basename="${post##*/}"
  # Skip Spanish posts (lang: es) — they're generated by translate-post.sh, not synced from blog/
  if grep -q "^lang: es" "$post" 2>/dev/null; then
    continue
  fi
  if [[ -z "${synced_posts[$basename]:-}" ]]; then
    rm "$post"
  fi
done

# Commit changes in Writing repo if it exists
WRITING_REPO="$(cd "$BLOG_SRC" 2>/dev/null && cd .. && pwd 2>/dev/null)" || WRITING_REPO=""
if [[ -n "$WRITING_REPO" && -d "$WRITING_REPO/.git" ]]; then
  (
    cd "$WRITING_REPO"
    git add -A
    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -m "blog: rename posts to kebab-case with date" || true
    fi
  ) || true
fi

cd "$SITE_ROOT" || { echo "ERROR: cannot cd to $SITE_ROOT"; exit 1; }

# Stage changes
if ! git add -A 2>&1; then
  echo "ERROR: git add failed"
  exit 1
fi

# Check if there are changes
if git diff --cached --quiet 2>/dev/null; then
  echo "blog: no changes"
  exit 0
fi

# Commit
if ! git commit -m "blog: sync $(date +%Y-%m-%d\ %H:%M)" 2>&1; then
  echo "ERROR: git commit failed"
  exit 1
fi

# Push (warn but don't fail)
if ! git push 2>&1; then
  echo "⚠️  git push failed (auth, network, or remote issue) — commit is local"
  exit 0
fi
EOF
chmod +x "$SITE_REPO/sync-from-blog.sh"
echo "✓ Created/updated sync script at $SITE_REPO/sync-from-blog.sh"

# Create systemd units (idempotent)
mkdir -p "$SYSTEMD_USER_DIR"

cat > "$SYSTEMD_USER_DIR/blog-sync.service" << EOF
[Unit]
Description=Sync blog posts to site and push

[Service]
Type=oneshot
ExecStart=$SITE_REPO/sync-from-blog.sh
Environment=PATH=/usr/local/bin:/usr/bin:/bin
EOF
echo "✓ Created/updated $SYSTEMD_USER_DIR/blog-sync.service"

cat > "$SYSTEMD_USER_DIR/blog-sync.path" << 'EOF'
[Unit]
Description=Watch ~/Documents/Writing/blog for changes

[Path]
PathModified=%h/Documents/Writing/blog
Unit=blog-sync.service

[Install]
WantedBy=default.target
EOF
echo "✓ Created/updated $SYSTEMD_USER_DIR/blog-sync.path"

# Enable and start (idempotent — safe if already enabled)
if command -v systemctl &>/dev/null; then
  systemctl --user daemon-reload
  systemctl --user enable --now blog-sync.path 2>/dev/null || true
  echo "✓ Enabled and started blog-sync.path"
else
  echo "⚠️  systemctl not found — skipping systemd setup"
  echo "   Manually enable: systemctl --user enable --now $SYSTEMD_USER_DIR/blog-sync.path"
fi

echo ""
echo "✅ Blog sync installed!"
echo ""
echo "📋 What's next:"
if [[ ! -d "$SITE_REPO/.git" ]]; then
  echo "   1. Set up your site repo at $SITE_REPO (clone, init, etc.)"
  echo "   2. Ensure git remote is configured for pushes"
  echo "   3. Authenticate with GitHub (ssh keys or gh auth login)"
fi
echo "   • Any .md file you create/edit/delete in $BLOG_DIR"
echo "     will auto-sync to $SITE_REPO/_posts/ within ~2 seconds"
echo "   • If push fails: check auth with 'ssh -T git@github.com'"
echo "     or 'gh auth login' for HTTPS"
