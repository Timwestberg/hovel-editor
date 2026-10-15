# Hovel engine modules

Each folder here is a Godot C++ module (`config.py`, `SCsub`,
`register_types.h`, `register_types.cpp`). `hovel/profile.py` adds this folder
to `custom_modules`, so the editor and every export template build the same
modules.

Follow Godot's guide for the pinned version:
[Custom modules in C++](https://docs.godotengine.org/en/latest/engine_details/architecture/custom_modules_in_cpp.html).

Prefer an editor plugin or a GDExtension when one can do the job. A module is
for code that must ship inside the engine on every platform.
