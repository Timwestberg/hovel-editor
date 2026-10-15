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
version="$(git show "$target:version.py" | awk -F' = ' '
  {gsub(/"/, "", $2)}
  $1 == "major" {M = $2} $1 == "minor" {m = $2} $1 == "patch" {p = $2} $1 == "status" {s = $2}
  END {v = M "." m; if (p != "" && p != "0") v = v "." p; print v "." s}')"
message="Merge upstream Godot $ref ${target:0:10} ($version)"
echo "Moving from upstream $current_ref (${current:0:10}) to $ref (${target:0:10}, $version)."

# Record the upstream commit as a parent, then take its tree and put hovel/ back.
git merge --no-ff --no-commit --allow-unrelated-histories -s ours "$target" > /dev/null
git read-tree -u --reset "$target"
git checkout "$prev" -- hovel
printf '%s %s\n' "$ref" "$target" > hovel/UPSTREAM

# Re-apply each allowed core change on top of the new upstream file. Keep going
# after a conflict so every listed path is applied, then stop for resolution.
conflicts=""
while read -r path; do
  patch="$(git diff --binary "$current" "$prev" -- "$path")"
  [[ -z "$patch" ]] || printf '%s\n' "$patch" | git apply --3way --index || conflicts+="  $path"$'\n'
done < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' hovel/CORE_CHANGES)
if [[ -n "$conflicts" ]]; then
  printf 'sync-upstream.sh: these paths conflict with upstream:\n%s' "$conflicts" >&2
  echo "Resolve them, then run:" >&2
  echo "  git add -A && git commit -m \"$message\" && hovel/scripts/check-divergence.sh" >&2
  exit 1
fi

git add -A
git commit -m "$message"

hovel/scripts/check-divergence.sh
