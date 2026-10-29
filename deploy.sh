#!/usr/bin/env bash
# Deploy the legal pages to Railway from WSL or Linux.
#
#   bash deploy.sh                deploy, then check the live site matches this folder
#   bash deploy.sh --dry-run      do every check and the copy, but upload nothing
#   bash deploy.sh --verify-only  only compare the live site with this folder
#   bash deploy.sh -y             skip the "did you update the changelog?" question
#
# Why it copies first: uploading straight from a Windows drive (/mnt/c) made Railway's builder report NUL bytes in
# plain files. A copy on the Linux disk deploys cleanly, so this script always deploys from one.
#
# Needs: the Railway CLI on your PATH and `railway login` done once. See README.md.

set -euo pipefail

PROJECT_ID="${RAILWAY_PROJECT_ID:-11949f62-4889-40d6-b984-cb6b306423a0}"   # an identifier, not a secret
ENVIRONMENT="${RAILWAY_ENVIRONMENT:-production}"
SERVICE="${RAILWAY_SERVICE:-verlet-legal}"
SITE="${SITE_URL:-https://privacy.verlet.co}"
COPY_DIR="${DEPLOY_COPY_DIR:-$HOME/verlet-legal-deploy}"

DRY_RUN=0; VERIFY_ONLY=0; ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\n== %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Compare the two public pages on the live site with the files in this folder.
verify_live() {
  local ok=1 tries="${1:-1}" i
  for i in $(seq 1 "$tries"); do
    ok=1
    for page in "/:public/index.html" "/ego/:public/ego/index.html"; do
      url_path="${page%%:*}"; file="${page#*:}"
      want="$(sha256sum "$SRC/$file" | cut -d' ' -f1)"
      got="$(curl -fsS -m 20 "$SITE$url_path" 2>/dev/null | sha256sum | cut -d' ' -f1 || true)"
      if [ "$want" = "$got" ]; then printf '  ok       %s\n' "$SITE$url_path"
      else printf '  DIFFERS  %s  (live is not the file in this folder)\n' "$SITE$url_path"; ok=0; fi
    done
    [ "$ok" = 1 ] && return 0
    [ "$i" -lt "$tries" ] && { echo "  waiting 10 s for the new version to go live..."; sleep 10; }
  done
  return 1
}

if [ "$VERIFY_ONLY" = 1 ]; then
  say "Comparing $SITE with this folder"
  verify_live 1 && { echo "The live site matches."; exit 0; } || die "The live site does not match this folder."
fi

command -v railway >/dev/null || die "The Railway CLI is not installed. See the README: 'Deploying from your computer'."
command -v curl >/dev/null || die "curl is not installed."

say "1/5 Checking the files"
for f in Dockerfile Caddyfile public/index.html public/ego/index.html; do
  [ -f "$SRC/$f" ] || die "Missing $f"
done
# Plain text only: a NUL byte in any file means something has gone wrong with how it was saved (for example a
# PowerShell redirect writes UTF-16), and Railway's build will fail on it.
bad=0
while IFS= read -r -d '' f; do
  if [ "$(tr -cd '\000' < "$f" | wc -c)" -gt 0 ]; then echo "  NUL bytes in: $f"; bad=1; fi
done < <(find "$SRC" -type f -not -path '*/.git/*' -print0)
[ "$bad" = 0 ] || die "Fix the file(s) above (re-save as UTF-8) and run again."
echo "  all files are plain text"

say "2/5 Checking git"
if git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
    echo "  You have uncommitted changes. They will be deployed, but they are not in git yet:"
    git -C "$SRC" status --short | sed 's/^/    /'
  else echo "  working tree is clean"; fi
fi
if [ "$ASSUME_YES" = 0 ] && [ "$DRY_RUN" = 0 ]; then
  echo "  If a policy's text changed: did you update 'Last updated' on the page and add a line to CHANGELOG.md?"
  read -r -p "  Continue? [y/N] " answer
  case "$answer" in y|Y|yes) ;; *) die "Stopped. Update the changelog, then run again." ;; esac
fi

say "3/5 Copying to the Linux disk ($COPY_DIR)"
rm -rf "$COPY_DIR"; mkdir -p "$COPY_DIR"
(cd "$SRC" && tar --exclude=.git --exclude=.railway -cf - .) | (cd "$COPY_DIR" && tar -xf -)
(cd "$SRC" && find . -type f -not -path './.git/*' | sort | while read -r f; do
  [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$(sha256sum "$COPY_DIR/$f" | cut -d' ' -f1)" ] || { echo "copy differs: $f" >&2; exit 1; }
done) || die "The copy is not identical to the source."
echo "  copied $(find "$COPY_DIR" -type f | wc -l) files, byte-identical"

if [ "$DRY_RUN" = 1 ]; then
  say "Dry run: nothing uploaded"
  echo "  would run: railway up --ci --service $SERVICE --project $PROJECT_ID --environment $ENVIRONMENT  (from $COPY_DIR)"
  exit 0
fi

say "4/5 Uploading to Railway"
( cd "$COPY_DIR" && railway up --ci --service "$SERVICE" --project "$PROJECT_ID" --environment "$ENVIRONMENT" ) \
  || die "The Railway build or upload failed. Run: railway logs --build --lines 80"

say "5/5 Checking the live site ($SITE)"
verify_live 9 || die "The upload finished but the live site still differs after 90 s. Check: railway status"
echo
echo "Deployed. $SITE/ego/ is live and matches this folder."
