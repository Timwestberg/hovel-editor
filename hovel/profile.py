# SCons build profile for every Hovel build: the editor and each export template.
# Pass it with `profile=hovel/profile.py`, or use hovel/scripts/build.sh, which does.
# Command-line arguments still override anything set here.

# Hovel's own engine modules. They live here, not in modules/, so upstream
# merges never touch them.
custom_modules = "hovel/modules"
