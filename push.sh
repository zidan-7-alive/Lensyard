#!/bin/sh
# Upload this folder to GitHub from Termux (or any shell with git).
# 1) Create an EMPTY repo on github.com (no README, no license).
# 2) Make a Personal Access Token (Settings > Developer settings > Tokens) with "repo" scope.
# 3) Run:  sh push.sh YOUR_GITHUB_USERNAME YOUR_REPO_NAME
#    When git asks for a password, paste the token (not your account password).
set -e
USER_NAME=${1:?usage: sh push.sh <github-username> <repo-name>}
REPO=${2:?usage: sh push.sh <github-username> <repo-name>}
command -v git >/dev/null 2>&1 || { echo "Install git first (Termux: pkg install git)"; exit 1; }
cd "$(dirname "$0")"
[ -d .git ] || git init
git checkout -B main
git add -A
git -c user.name="$USER_NAME" -c user.email="$USER_NAME@users.noreply.github.com" commit -m "Whodunit v1.3.3" || true
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$USER_NAME/$REPO.git"
git push -u origin main
echo "Done: https://github.com/$USER_NAME/$REPO"
