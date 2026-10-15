#!/usr/bin/env bash
# Build the Hovel editor or an export template with Hovel's profile.
#
#   hovel/scripts/build.sh editor              # editor for this machine
#   hovel/scripts/build.sh web                 # non-threaded Web release template
#   hovel/scripts/build.sh android             # arm64 Android release template
#   hovel/scripts/build.sh ios                 # iOS release template (macOS only)
#   hovel/scripts/build.sh <target> [scons args...]
#
# Extra arguments go straight to scons, for example `target=template_debug`.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

what="${1:-}"
[[ -n "$what" ]] || { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
shift

case "$what" in
  editor)
    case "$(uname -s)" in
      Darwin) platform=macos ;;
      Linux) platform=linuxbsd ;;
      MINGW* | MSYS* | CYGWIN*) platform=windows ;;
      *) echo "build.sh: unknown host $(uname -s); pass platform=..." >&2; exit 2 ;;
    esac
    args=(platform="$platform" target=editor)
    ;;
  # Hovel's Web preset is non-threaded, so the template must be too.
  web) args=(platform=web target=template_release threads=no) ;;
  android) args=(platform=android target=template_release arch=arm64) ;;
  ios) args=(platform=ios target=template_release) ;;
  *) echo "build.sh: unknown target '$what' (editor, web, android, ios)" >&2; exit 2 ;;
esac

exec scons profile=hovel/profile.py "${args[@]}" "$@"
