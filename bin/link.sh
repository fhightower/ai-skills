#!/usr/bin/env bash
#
# Symlink this repo's skills into ~/.claude/skills/ so Claude Code picks them up.
#
# Safe by design: never deletes a real directory, never overwrites a symlink
# owned by a different repo. On conflict it reports and skips.
#
# Usage:
#   bin/link.sh              link all skills
#   bin/link.sh --dry-run    show what would happen, change nothing
#   bin/link.sh --prune      also remove symlinks into this repo whose source is gone

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

DRY_RUN=false
PRUNE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --prune)   PRUNE=true ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

linked=0; skipped=0; conflicts=0; pruned=0

say() { $DRY_RUN && echo "[dry-run] $*" || echo "$*"; }

if [ ! -d "$SRC_DIR" ]; then
  echo "no skills/ directory at $SRC_DIR" >&2
  exit 1
fi

$DRY_RUN || mkdir -p "$DEST_DIR"

for src in "$SRC_DIR"/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  src="${src%/}"
  dest="$DEST_DIR/$name"

  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    say "link    $name"
    $DRY_RUN || ln -s "$src" "$dest"
    linked=$((linked + 1))

  elif [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      skipped=$((skipped + 1))
    else
      echo "CONFLICT $name -> already symlinked to $current" >&2
      conflicts=$((conflicts + 1))
    fi

  else
    echo "CONFLICT $name -> a real directory already exists at $dest" >&2
    echo "         move it into $SRC_DIR first, then re-run" >&2
    conflicts=$((conflicts + 1))
  fi
done

if $PRUNE; then
  for dest in "$DEST_DIR"/*; do
    [ -L "$dest" ] || continue
    target="$(readlink "$dest")"
    case "$target" in
      "$SRC_DIR"/*)
        if [ ! -d "$target" ]; then
          say "prune   $(basename "$dest") (source gone)"
          $DRY_RUN || rm "$dest"
          pruned=$((pruned + 1))
        fi
        ;;
    esac
  done
fi

echo "linked=$linked already=$skipped pruned=$pruned conflicts=$conflicts"
[ "$conflicts" -eq 0 ] || exit 1
