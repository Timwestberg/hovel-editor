# Hovel editor

This repository is a fork of [godotengine/godot](https://github.com/godotengine/godot)
that builds the Hovel editor and every Hovel engine (Web, Android, iOS) from one
source. Hovel adds tooling on top of Godot; it does not change Godot itself.

## Branches

| Branch | What it is |
| --- | --- |
| `master` | An untouched mirror of upstream `master`. Use GitHub's **Sync fork**; never commit to it. |
| `hovel/main` | The upstream commit in `hovel/UPSTREAM` plus the `hovel/` folder. Every Hovel build comes from here. |
| `hovel/<topic>` | Work in progress. Branch from `hovel/main` and open a PR back into it. |

## The one rule

Every Hovel change lives under `hovel/`: engine modules in `hovel/modules/`,
build options in `hovel/profile.py`, scripts in `hovel/scripts/`. Editor plugins
and GDExtensions that do not need the engine rebuilt belong in the game project,
not here.

`hovel/scripts/check-divergence.sh` fails when anything outside `hovel/` differs
from that upstream commit. If a change to Godot itself is truly unavoidable, list its
path in `hovel/CORE_CHANGES` with the reason, and try to send it upstream so the
entry can be removed later.

## Which Godot

`hovel/main` follows upstream `master`, currently the 4.8 beta. There are no
official export templates for an unreleased build, so Hovel uses templates
built here with `hovel/scripts/build.sh`. To settle on a release instead, run
the sync script with its tag (for example `4.8-stable`).

## Building

Follow Godot's [building from source](https://docs.godotengine.org/en/latest/engine_details/development/compiling/index.html)
guide to install SCons and each platform's toolchain,
then:

```sh
hovel/scripts/build.sh editor     # the editor for this machine
hovel/scripts/build.sh web        # non-threaded Web release template (needs Emscripten)
hovel/scripts/build.sh android    # arm64 Android release template and library (see below)
hovel/scripts/build.sh ios        # iOS release template (macOS with Xcode)
```

Each build uses `hovel/profile.py`, so the editor and every template include the
same modules in `hovel/modules/`. Extra arguments go to SCons, for example
`hovel/scripts/build.sh web target=template_debug`.

## Android library

`hovel/scripts/build.sh android` builds the arm64 release template with Hovel's
profile, then runs Godot's Gradle step to produce the Godot Android library
(AAR). Gamero embeds this library to run Hovel natively on Android. There is no
official library for the 4.8 beta on Maven Central, so it must come from here.

Prerequisites:

- JDK 17
- The Android SDK, with `ANDROID_HOME` set to its folder
- NDK `29.0.14206865` (SCons installs it with `sdkmanager` when the SDK's
  cmdline-tools are present)

Output in `bin/`:

| File | What it is |
| --- | --- |
| `godot-lib.template_release.aar` | The Android library Gamero embeds |
| `android_release.apk` | The Android export template |
| `android_source.zip` | The Gradle build template for exports |

`hovel/scripts/build.sh android target=template_debug` gives
`godot-lib.template_debug.aar` and `android_debug.apk` instead.

The script fails if `ANDROID_HOME` does not point to a folder, and exits 1 if
the AAR is missing or older than the build, because Godot's Gradle step does
not fail the SCons build on its own. Rerun Gradle by hand to see the error:
`(cd platform/android/java && ./gradlew generateGodotTemplates)`.
Each build first deletes the AAR for its target, so a failed build leaves no
AAR in `bin/`; copy one out first if you need to keep it.

Gamero uses only an AAR built from `hovel/main`, so the library has the same
Godot commit and modules as the editor and the Web template.

## Syncing with upstream

```sh
git switch -c hovel/sync-upstream hovel/main
hovel/scripts/sync-upstream.sh            # latest upstream master
hovel/scripts/sync-upstream.sh 4.8-stable # or a release tag
```

The script takes upstream's files everywhere outside `hovel/`, keeps `hovel/`,
re-applies anything in `hovel/CORE_CHANGES`, records the new ref and commit in
`hovel/UPSTREAM`, and runs the divergence check. It works the same for a day's
worth of master commits and for a jump between major versions. Open a PR into
`hovel/main`, then rebuild the editor and templates and run the Hovel checks in
game-platform before merging.

## License

Godot is MIT licensed; keep `LICENSE.txt`, `COPYRIGHT.txt` and
`AUTHORS.md` as upstream ships them. "Godot" is a trademark of the Godot
Foundation; see its [trademark policy](https://godot.foundation/trademark-policy/)
before naming any build you distribute.
