# Euler Disk Simulation

This repository is a cleaned-up and lightly modernized working copy of Milan
Batista's Euler disk simulation program:

<https://fpp.edu/~milanb/euler/>

The original project provides the Fortran Euler disk model and Windows
simulation program. This copy keeps that core code, adds a simpler `run.bat`
workflow, preset input files, and a native OpenGL viewer that builds with
gfortran/gcc.

Generated binaries, plots, CSVs, and simulation output are intentionally kept
out of the active source layout. If they already exist locally, they can be
regenerated from the commands below.

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

Open the no-solver initial-condition visualizer:

```bat
.\view_initial.bat
```

The visualizer opens an interactive native OpenGL window. Drag the sliders to
change radius, height, initial Euler angles, and `omega1..omega3` without
running the solver. You can optionally pass a `.responses` file to use it as a
starting preset.

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

`generated/` is for search CSVs, plots, and copied best-run reports. The active
tooling writes there by default, but the source of truth is the scripts and
presets.

## Source Layout

| Path | Role |
| --- | --- |
| `run.bat` | Current build/run workflow. |
| `view_initial.bat` | Builds and opens the no-solver initial-condition visualizer. |
| `model2/` | Disk physics, simulation input, integration, event handling, and output writing. |
| `screen/` | Legacy console input and expression-parsing helpers used by `model2/input.f90`. |
| `hairer/` | Hairer/Wanner DOPRI5 and DOP853 ODE solver sources. |
| `edisk_gl_viewer.c` | Native OpenGL viewer for `animat.txt`. |
| `edisk_ic_viewer.c` | Native OpenGL viewer for initial rotations and omega components. |
| `init/` | Preset response files for reproducible runs. |
| `tools/` | Python analysis, launch-search, and plotting helpers. |
| `archive/` | Historical/reference material that is not part of the active build. |

More detail is in `docs/CODE_REFERENCE.md` and `docs/PHYSICS_MODEL.md`.

## Python Tools

| Command | Purpose |
| --- | --- |
| `py -3 tools\launch_parameter_search.py` | Search release theta and impact theta; geometry stays at the preset unless explicitly varied. |
| `py -3 tools\launch_search_heatmap.py` | Plot heatmaps from a launch-parameter-search CSV. |
| `py -3 tools\strike_angle_scan.py` | Hold release/impact theta fixed, scan strike direction, and plot lifetime/contact mode over time. |
| `py -3 tools\score_paired_impulse_grid.py` | Score paired face-impulse geometry without running the simulator. |
| `py -3 tools\show_paired_impulse_geometry.py` | Draw a 3D paired-impulse geometry diagnostic. |
| `py -3 tools\pendulum_rod.py` | Inspect the fixed physical pendulum release/impact angles and effective mass. |

For double-click use, run `search_launch_parameters.bat` or
`scan_strike_angle.bat`. Each file has an `ARGS` line near the top for changing
the defaults without typing commands.

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
