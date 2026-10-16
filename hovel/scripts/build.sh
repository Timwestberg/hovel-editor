#!/usr/bin/env bash
# Build the Hovel editor or an export template with Hovel's profile.
#
#   hovel/scripts/build.sh editor              # editor for this machine
#   hovel/scripts/build.sh web                 # non-threaded Web release template
#   hovel/scripts/build.sh android             # arm64 Android release template and library (AAR)
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
  # Also runs Gradle for the library (AAR), the APK template and android_source.zip.
  android) args=(platform=android target=template_release arch=arm64 generate_android_binaries=yes) ;;
  ios) args=(platform=ios target=template_release) ;;
  *) echo "build.sh: unknown target '$what' (editor, web, android, ios)" >&2; exit 2 ;;
esac

if [[ "$what" != android ]]; then
  exec scons profile=hovel/profile.py "${args[@]}" "$@"
fi

# Android: the last target= wins, as in SCons. Godot's Gradle step does not
# fail the SCons build, so check the AAR it should have written.
target=template_release
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
for arg in "$@"; do
  case "$arg" in
    target=*) target="${arg#target=}" ;;
    ANDROID_HOME=*) sdk="${arg#ANDROID_HOME=}" ;;
  esac
done

case "$target" in
  template_release | template_debug) ;;
  *) echo "build.sh: android builds target=template_release or target=template_debug, not '$target'." >&2; exit 2 ;;
esac

if [[ -z "$sdk" || ! -d "$sdk" ]]; then
  echo "build.sh: Android SDK not found (ANDROID_HOME='$sdk'). Install the Android SDK and NDK 29.0.14206865, then set ANDROID_HOME to the SDK folder." >&2
  exit 1
fi
# SCons and Godot's Gradle step both read ANDROID_HOME, so give them the same SDK.
export ANDROID_HOME="$sdk"

aar="bin/godot-lib.${target}.aar"
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
# Remove the old AAR so an up-to-date Gradle copy cannot leave it in place.
rm -f "$aar"

scons profile=hovel/profile.py "${args[@]}" "$@"

if [[ ! -f "$aar" || ! "$aar" -nt "$stamp" ]]; then
  echo "build.sh: $aar is missing or older than this build, so Gradle failed." >&2
  echo "Rerun it by hand to see why: (cd platform/android/java && ./gradlew generateGodotTemplates)" >&2
  exit 1
fi
echo "build.sh: wrote $aar"
