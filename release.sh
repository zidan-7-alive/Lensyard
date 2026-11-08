#!/bin/sh
# One-command release from Termux. Builds the zip, pushes the code, publishes a GitHub Release,
# then updates update.json so every phone gets the update from its root manager (OTA).
#
#   sh release.sh                          release the version already in module/module.prop
#   sh release.sh v2.3.0 "What changed"    bump the version, add a changelog line, then release
#
# One-time setup:  pkg install git python gh   and   gh auth login
set -e
cd "$(dirname "$0")"
REPO="zidan-7-alive/Lensyard"
PY=$(command -v python || command -v python3 || true)
[ -n "$PY" ] || { echo "Need python: pkg install python"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Need git: pkg install git"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "Need the GitHub CLI: pkg install gh   then   gh auth login"; exit 1; }

if [ -n "$1" ]; then
  VER=$1; NOTES=${2:-Update}
  case "$VER" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "Version must look like v2.3.0"; exit 1 ;; esac
  CODE=$(grep '^versionCode=' module/module.prop | cut -d= -f2); CODE=$((CODE + 1))
  sed -i "s/^version=.*/version=$VER/; s/^versionCode=.*/versionCode=$CODE/" module/module.prop
  { printf '# Changelog\n\n## %s\n- %s\n' "$VER" "$NOTES"; tail -n +2 CHANGELOG.md; } > .cl.tmp && mv .cl.tmp CHANGELOG.md
fi
VER=$(grep '^version=' module/module.prop | cut -d= -f2)
CODE=$(grep '^versionCode=' module/module.prop | cut -d= -f2)
ZIP="dist/Lensyard-$VER.zip"

echo "Building $VER (code $CODE)..."
"$PY" tools/package.py module --out dist
[ -f "$ZIP" ] || { echo "Build failed: $ZIP not found"; exit 1; }

git add -A
git commit -m "Lensyard $VER" || true
git push

awk '/^## /{n++} n==1' CHANGELOG.md | tail -n +2 > .notes.tmp
if gh release view "$VER" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$VER" "$ZIP" --clobber --repo "$REPO"
else
  gh release create "$VER" "$ZIP" --repo "$REPO" --title "Lensyard $VER" --notes-file .notes.tmp
fi
rm -f .notes.tmp

# Publish the OTA pointer only now, after the zip exists, so no phone is ever sent to a dead link.
cat > update.json <<JSON
{
  "version": "$VER",
  "versionCode": $CODE,
  "zipUrl": "https://github.com/$REPO/releases/download/$VER/Lensyard-$VER.zip",
  "changelog": "https://raw.githubusercontent.com/$REPO/main/CHANGELOG.md"
}
JSON
git add update.json
git commit -m "OTA: $VER" || true
git push
echo "Done. Lensyard $VER is live; phones will offer the update in their root manager."
