# Euler Disk Simulation

This repository is a cleaned-up and lightly modernized working copy of Milan
Batista's Euler disk simulation program:

https://fpp.edu/~milanb/euler/

The original project provides the Fortran Euler disk model and Windows
simulation program. This copy keeps that core code, adds a simpler `run.bat`
workflow, preset input files, and a native OpenGL viewer that builds with
gfortran/gcc.

The normal entry point is:

```bat
.\run.bat init\manual.responses
```

`run.bat` builds the Fortran simulation, feeds it the selected initial-condition
file, writes fresh output files in the repository root, and opens the viewer
unless `EDISK_NO_VIEW=1` is set.

## Common Commands

Run a preset and open the viewer:

```bat
.\run.bat init\manual.responses
```

Run a preset without opening the viewer:

```powershell
$env:EDISK_NO_VIEW='1'; cmd /c run.bat init\manual.responses
```

Open the current animation manually:

```bat
.\build_gfortran\edisk_gl_viewer.exe animat.txt
```

Run interactively, using the Fortran prompts:

```bat
.\run.bat
```

## Output Files

Each simulation writes these root-level files:

| File | Meaning |
| --- | --- |
| `animat.txt` | Time-sampled animation data consumed by `edisk_gl_viewer.exe`. |
| `result.txt` | Numeric state history from the integrator. |
| `report.txt` | Human-readable run summary, parameters, energy values, and launch diagnostics. |

These filenames are fixed in `model2/disk_data.f90`. Running the simulation
again overwrites the current versions.

## Generated Files

`build_gfortran/` is a compiler output folder. It should normally contain only:

- `edisk_headless.exe`
- `edisk_gl_viewer.exe`
- `libfreeglut__.dll`
- Fortran `.o` and `.mod` files
- the tiny temporary file `input_responses.tmp`

The folder can be deleted and regenerated with `run.bat`. It should not be used
to store experiment results.

## Source Layout

| Path | Role |
| --- | --- |
| `run.bat` | Current build/run workflow. |
| `model2/` | Disk physics, simulation input, integration, event handling, and output writing. |
| `screen/` | Legacy console input and expression-parsing helpers used by `model2/input.f90`. |
| `hairer/` | Hairer/Wanner DOPRI5 and DOP853 ODE solver sources. |
| `edisk_gl_viewer.c` | Native OpenGL viewer for `animat.txt`. |
| `init/` | Preset response files for reproducible runs. |
| `archive/` | Historical/reference material that is not part of the active build. |

More detail is in `docs/CODE_REFERENCE.md` and `docs/PHYSICS_MODEL.md`.

## Viewer Controls

| Control | Action |
| --- | --- |
| Left mouse drag | Orbit camera. |
| Middle or right mouse drag | Pan. |
| Mouse wheel | Zoom. |
| Space | Play or pause. |
| `r` | Restart playback. |
| `+` / `-` | Increase or decrease playback speed. |
| `1`, `2`, `5`, `0` | Set speed to 1x, 2x, 5x, or 10x. |
| `g` | Toggle grid. |
| `p` | Toggle contact path. |
| `t` | Toggle text overlay. |
| `Esc` or `q` | Quit. |
