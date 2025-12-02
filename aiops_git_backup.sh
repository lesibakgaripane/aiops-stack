#!/usr/bin/env bash
set -e

echo "=============================="
echo " AIOps Git Backup"
echo " Repo:  $(pwd)"
echo " Time:  $(date)"
echo "=============================="

# Optional commit message from first argument, otherwise auto-generate
MSG="$1"
if [ -z "$MSG" ]; then
  MSG="AIOps auto-backup $(date '+%F %H:%M:%S')"
fi

# Show current branch and remote
echo
echo "[1] Git status & remote"
git status -sb || exit 1
echo
git remote -v

# Stage everything (same behaviour as you just did manually)
echo
echo "[2] Staging changes (git add .)"
git add .

# Check if there is anything to commit
if git diff --cached --quiet; then
  echo
  echo "No changes to commit. Working tree is clean."
  exit 0
fi

echo
echo "[3] Committing with message:"
echo "    \"$MSG\""
git commit -m "$MSG"

echo
echo "[4] Pushing to remote (default: origin/master)"
git push

echo
echo "✅ Git backup complete."
