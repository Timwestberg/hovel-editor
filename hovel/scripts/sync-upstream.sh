#!/usr/bin/env bash
# Move the current branch (normally a branch off hovel/main) to the latest
# commit of an upstream Godot branch or tag.
#
#   hovel/scripts/sync-upstream.sh               # the ref in hovel/UPSTREAM (master)
#   hovel/scripts/sync-upstream.sh 4.8-stable    # switch to a release tag
#
# Upstream wins everywhere outside hovel/. The result is one merge commit whose
# parents are the old branch and the new upstream commit, so history stays
# intact without hand-resolving Godot's own files. Paths in hovel/CORE_CHANGES
# get their Hovel diff re-applied with a 3-way apply; a conflict there stops the
# script for you to resolve. Open a PR into hovel/main with the result.
#
# Needs real history for the 3-way apply: run it in a full clone, not --depth 1.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

read -r current_ref current < hovel/UPSTREAM
ref="${1:-$current_ref}"
[[ -z "$(git status --porcelain)" ]] || { echo "sync-upstream.sh: commit or stash your changes first" >&2; exit 1; }

git remote get-url upstream > /dev/null 2>&1 \
  || git remote add upstream https://github.com/godotengine/godot.git
git fetch upstream "$ref"
target="$(git rev-parse 'FETCH_HEAD^{commit}')"
if [[ "$target" == "$current" ]]; then
  echo "Already on upstream $ref (${target:0:10})."
  exit 0
fi
git cat-file -e "$current^{commit}" 2> /dev/null || git fetch --depth 1 upstream "$current"
prev="$(git rev-parse HEAD)"
version="$(git show "$target:version.py" | sed -n 's/^\(major\|minor\|status\) = "\{0,1\}\([^"]*\)"\{0,1\}$/\2/p' | paste -sd. -)"
echo "Moving from upstream $current_ref (${current:0:10}) to $ref (${target:0:10}, $version)."

# Record the upstream commit as a parent, then take its tree and put hovel/ back.
git merge --no-ff --no-commit --allow-unrelated-histories -s ours "$target" > /dev/null
git read-tree -u --reset "$target"
git checkout "$prev" -- hovel

# Re-apply each allowed core change on top of the new upstream file.
sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' hovel/CORE_CHANGES | while read -r path; do
  patch="$(git diff --binary "$current" "$prev" -- "$path")"
  [[ -z "$patch" ]] || printf '%s\n' "$patch" | git apply --3way --index
done

printf '%s %s\n' "$ref" "$target" > hovel/UPSTREAM
git add -A
git commit -m "Merge upstream Godot $ref ${target:0:10} ($version)"

hovel/scripts/check-divergence.sh
