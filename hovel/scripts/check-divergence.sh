#!/usr/bin/env bash
# Fail when the branch changes a file outside hovel/ compared with the upstream
# commit in hovel/UPSTREAM. Hovel adds tooling; it does not edit Godot.
#
# A change to Godot itself is allowed only when its path is listed in
# hovel/CORE_CHANGES, one path per line with the reason in a trailing comment.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

read -r ref base < hovel/UPSTREAM
if ! git cat-file -e "$base^{commit}" 2> /dev/null; then
  git remote get-url upstream > /dev/null 2>&1 \
    || git remote add upstream https://github.com/godotengine/godot.git
  git fetch --depth 1 upstream "$base" > /dev/null
fi

allowed="$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' hovel/CORE_CHANGES 2>/dev/null || true)"
changed="$(git diff --name-only "$base" HEAD -- . ':(exclude)hovel')"
unexpected="$(comm -23 <(printf '%s\n' "$changed" | sed '/^$/d' | sort) <(printf '%s\n' "$allowed" | sort))"

if [[ -n "$unexpected" ]]; then
  echo "These files differ from upstream $ref (${base:0:10}) but are not in hovel/CORE_CHANGES:" >&2
  printf '  %s\n' $unexpected >&2
  echo "Move the change into hovel/, or list the path in hovel/CORE_CHANGES with a reason." >&2
  exit 1
fi
echo "Only hovel/ differs from upstream $ref (${base:0:10})$( [[ -n "$allowed" ]] && echo ", plus the paths in hovel/CORE_CHANGES")."
