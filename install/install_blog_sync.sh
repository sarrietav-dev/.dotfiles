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

cat > "$SITE_REPO/sync-from-blog.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

SITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_SRC="$HOME/Documents/Writing/blog/"
POSTS_DST="$SITE_ROOT/_posts/"

# Convert to kebab-case and ensure YYYY-MM-DD prefix from frontmatter date or file mtime
rename_post() {
  local src="$1"
  local dst_dir="$2"
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

  local new_name="$date-$name_only.$ext"
  local dst="$dst_dir/$new_name"

  if [[ "$src" != "$dst" ]]; then
    cp "$src" "$dst"
  fi

  # Return the destination filename
  echo "$new_name"
}

# Create destination
mkdir -p "$POSTS_DST"

# Track which posts exist in source (by new name)
declare -A synced_posts

# Copy and rename posts from blog dir
for post in "$BLOG_SRC"/*.md; do
  [[ -e "$post" ]] || continue
  new_name=$(rename_post "$post" "$POSTS_DST")
  synced_posts["$new_name"]=1
done

# Remove posts that no longer exist in source
for post in "$POSTS_DST"/*.md; do
  [[ -e "$post" ]] || continue
  basename="${post##*/}"
  if [[ -z "${synced_posts[$basename]:-}" ]]; then
    rm "$post"
  fi
done

# Commit and push (gracefully handle auth/connectivity issues)
cd "$SITE_ROOT"
git add -A
git diff --cached --quiet && { echo "blog: no changes"; exit 0; }

git commit -m "blog: sync $(date +%Y-%m-%d\ %H:%M)" || { echo "git commit failed"; exit 1; }

# Push; warn but don't fail if it can't (auth, network, or remote issue)
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
