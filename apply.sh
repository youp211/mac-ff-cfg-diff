#!/bin/bash
# Safari-like Firefox on macOS = Lepton (Proton style) + the small diff in this repo.
#
#   ./apply.sh                      install into the default Firefox profile
#   ./apply.sh --check              report the current state, change nothing
#   ./apply.sh --profile <dir>      use a specific profile folder
#
# Safe to re-run. Each install first copies the profile's chrome/ folder and
# user.js to <profile>/safari-cfg-backup-<timestamp>/.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/youp211/mac-ff-cfg-diff/main"
LEPTON_REPO="https://github.com/black7375/Firefox-UI-Fix"
# Lepton's proton-style branch, pinned to the commit this diff was measured against.
LEPTON_REF="${LEPTON_REF:-cd75a42f9f067aea588014d24609d2712f0790cf}"

die() { echo "error: $*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Safari-like Firefox on macOS = Lepton (Proton style) + the small diff in this repo.

  apply.sh                      install into the default Firefox profile
  apply.sh --check              report the current state, change nothing
  apply.sh --profile <dir>      use a specific profile folder
USAGE
}

CHECK=0
PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1 ;;
    --profile) [ $# -ge 2 ] || die "--profile needs a folder"; PROFILE="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

[ "$(uname -s)" = "Darwin" ] || die "this setup is for Firefox on macOS"

# --- profile ----------------------------------------------------------------
if [ -z "$PROFILE" ]; then
  FF_DIR="$HOME/Library/Application Support/Firefox"
  INI="$FF_DIR/profiles.ini"
  [ -r "$INI" ] || die "cannot read $INI (start Firefox once, or pass --profile <dir>)"
  # The profile Firefox launches: the [Install...] default, else the Default=1 profile.
  REL="$(awk -F= '/^\[Install/{i=1;next} /^\[/{i=0} i&&$1=="Default"{print $2;exit}' "$INI")"
  [ -n "$REL" ] || REL="$(awk -F= '/^\[/{p=""} $1=="Path"{p=$2} $1=="Default"&&$2=="1"&&p!=""{print p;exit}' "$INI")"
  [ -n "$REL" ] || die "no default profile in $INI (pass --profile <dir>)"
  case "$REL" in /*) PROFILE="$REL" ;; *) PROFILE="$FF_DIR/$REL" ;; esac
fi
[ -d "$PROFILE" ] || die "profile folder not found: $PROFILE"
echo "Profile: $PROFILE"

# --- this repo's two diff files (next to the script, or fetched when piped from curl) ---
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
for f in userChrome.safari.css user-overrides.js; do
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$f" ]; then cp "$SRC_DIR/$f" "$WORK/$f"
  else curl -fsSL "$REPO_RAW/$f" -o "$WORK/$f" || die "cannot fetch $f"
  fi
done

UC="$PROFILE/chrome/userChrome.css"
UJ="$PROFILE/user.js"
pref_names() { awk -F'"' '/^[[:space:]]*user_pref\("/{print $2}' "$@"; }

if [ "$CHECK" = 1 ]; then
  if [ ! -f "$UC" ]; then echo "  userChrome.css: missing"
  elif ! grep -q 'css/lepton' "$UC"; then echo "  userChrome.css: present, but Lepton is not imported"
  elif awk '/safari-cfg:begin/{p=1} p{print} /safari-cfg:end/{p=0}' "$UC" | cmp -s - "$WORK/userChrome.safari.css"; then echo "  userChrome.css: up to date"
  elif grep -q 'safari-cfg:begin\|safari-fix:' "$UC"; then echo "  userChrome.css: has an older version of this diff"
  else echo "  userChrome.css: Lepton only, diff not applied"
  fi
  for p in $(pref_names "$WORK/user-overrides.js"); do
    want="$(grep -F "\"$p\"" "$WORK/user-overrides.js" | sed -E 's/^[^,]*,[[:space:]]*([^)]*)\).*/\1/')"
    have="$(grep -E "^[[:space:]]*user_pref\(\"$p\"," "$UJ" 2>/dev/null | tail -1 | sed -E 's/^[^,]*,[[:space:]]*([^)]*)\).*/\1/' || true)"
    if [ "$have" = "$want" ]; then echo "  $p: $have"; else echo "  $p: ${have:-not set} (want $want)"; fi
  done
  exit 0
fi

# --- Lepton, pinned ------------------------------------------------------------
echo "Fetching Lepton (proton-style) $LEPTON_REF"
mkdir "$WORK/lepton"
curl -fsSL "$LEPTON_REPO/archive/$LEPTON_REF.tar.gz" | tar -xz -C "$WORK/lepton" --strip-components 1 \
  || die "cannot download Lepton"
for f in userChrome.css userContent.css user.js css/leptonChrome.css icons; do
  [ -e "$WORK/lepton/$f" ] || die "unexpected Lepton layout: $f is missing"
done

# --- back up -------------------------------------------------------------------
BACKUP="$PROFILE/safari-cfg-backup-$(date +%Y%m%d-%H%M%S)"
if [ -d "$PROFILE/chrome" ] || [ -f "$UJ" ]; then
  mkdir -p "$BACKUP"
  if [ -d "$PROFILE/chrome" ]; then cp -R "$PROFILE/chrome" "$BACKUP/chrome"; fi
  if [ -f "$UJ" ]; then cp "$UJ" "$BACKUP/user.js"; fi
  echo "Backup of the previous files: $BACKUP"
fi

# --- theme files -----------------------------------------------------------------
mkdir -p "$PROFILE/chrome"
rm -rf "$PROFILE/chrome/css" "$PROFILE/chrome/icons"
cp -R "$WORK/lepton/css" "$WORK/lepton/icons" "$PROFILE/chrome/"
# Keep an existing userChrome.css / userContent.css that already imports Lepton
# (it may hold your own rules); otherwise install Lepton's.
for f in userChrome.css userContent.css; do
  if [ -f "$PROFILE/chrome/$f" ] && grep -q 'css/lepton' "$PROFILE/chrome/$f"; then :; else cp "$WORK/lepton/$f" "$PROFILE/chrome/$f"; fi
done
# userChrome.css = everything outside the managed block, then the current block.
awk '/safari-cfg:begin|safari-fix:/{skip=1} !skip{print} /safari-cfg:end/{skip=0}' "$UC" \
  | awk '{l[NR]=$0} END{n=NR; while(n>0 && l[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print l[i]}' > "$WORK/uc.css"
{ cat "$WORK/uc.css"; echo; cat "$WORK/userChrome.safari.css"; } > "$UC"

# --- prefs -------------------------------------------------------------------------
# user.js = any other prefs you already had + Lepton's defaults + this repo's overrides.
pref_names "$WORK/lepton/user.js" "$WORK/user-overrides.js" | sort -u > "$WORK/names"
{
  if [ -f "$UJ" ]; then
    awk 'NR==FNR{s[$0]=1;next} /^[[:space:]]*user_pref\("/{split($0,q,"\""); if(!(q[2] in s)) print}' "$WORK/names" "$UJ" > "$WORK/carried"
    if [ -s "$WORK/carried" ]; then echo "// Carried over from the previous user.js"; cat "$WORK/carried"; echo; fi
  fi
  cat "$WORK/lepton/user.js"
  echo
  cat "$WORK/user-overrides.js"
} > "$WORK/user.js"
cat "$WORK/user.js" > "$UJ"

echo "Installed. Quit and reopen Firefox to see it."
