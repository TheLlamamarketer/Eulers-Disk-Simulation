# Code Reference

This file describes the current active code. It is meant as a map for editing
or debugging the simulation, not as a history log.

## Build And Run Flow

`run.bat` is the current entry point.

1. Sets `BUILD=build_gfortran`.
2. If an `init/*.responses` file is passed, strips comments and blank lines into
   `build_gfortran/input_responses.tmp`.
3. Compiles the Fortran sources with `gfortran`.
4. Links `build_gfortran/edisk_headless.exe`.
5. Runs the simulation, which writes `animat.txt`, `result.txt`, and
   `report.txt` in the repository root.
6. Builds `build_gfortran/edisk_gl_viewer.exe` from `edisk_gl_viewer.c` if
   needed.
7. Opens the viewer unless `EDISK_NO_VIEW=1` is set.

The viewer is C/OpenGL. The physics simulation is Fortran.

## Active Fortran Modules

| File | Responsibility |
| --- | --- |
| `model2/main.f90` | Program entry point. Calls `input`, `integ`, then `post`. |
| `model2/input.f90` | Reads interactive or preset inputs. Owns disk geometry, friction parameters, manual launch inputs, and pendulum/double-pendulum strike inputs. |
| `model2/disk_data.f90` | Shared constants, state, filenames, disk geometry, derived mass, resistance lengths, and strike diagnostics. |
| `model2/prop.f` | Computes disk radii of gyration from geometry. |
| `model2/disk.f90` | Adapter passed to the ODE solver. |
| `model2/disk0.f90` | Core equations for rolling/sliding disk dynamics and contact forces. |
| `model2/integ.f90` | Opens output files, writes the report header, configures DOP853, runs integration, and handles mode restarts. |
| `model2/solout.f90` | Dense-output callback. Writes sampled state rows and detects stop or rolling/sliding events. |
| `model2/ztime.f90` | Event-time polynomial used by `solout.f90`. |
| `model2/post.f90` | Converts `result.txt` into `animat.txt`. |
| `zeroin.f` | Scalar root finder used for event timing. |

## Legacy Console Helpers

The `screen/` directory is still active because `model2/input.f90` uses its
prompt and parsing routines.

| File | Responsibility |
| --- | --- |
| `screen/mui.f90` | Prompting, validation, screen formatting, and user input wrappers. |
| `screen/mcalc.f90` | Numeric expression parser used by input prompts. |
| `screen/mchr.f90` | String helpers. |
| `screen/mio.f90` | Free-unit helper for Fortran file I/O. |
| `screen/mn2c.f90` | Number-to-character formatting helpers. |

## ODE Solver Sources

`hairer/` contains the active Hairer/Wanner solver code used by the integrator:

- `dopri5.for`, `cdopri.for`, `contd5.for`
- `dop853.for`, `dopcor.for`, `contd8.for`, `dp86co.for`
- `hinit.for`

These are vendor-style numerical routines. They are part of the active build,
but ordinary physics changes should usually happen in `model2/`.

## Viewer

`edisk_gl_viewer.c` reads `animat.txt`. If a `report.txt` exists next to the
animation file, the viewer also reads it for extra run metadata such as
single- or double-pendulum strike diagnostics.

The viewer renders a rounded disk mesh with OpenGL depth testing. It interpolates
animation frames by simulation time and uses quaternion interpolation for disk
orientation, which avoids visible jumps when Euler angles wrap or cross awkward
branches.

## Python Tools

Python utilities live under `tools/`. The active launch-search scripts share
common preset parsing, simulator output parsing, and preflight math through
`tools/launch_model.py`.

| File | Responsibility |
| --- | --- |
| `tools/launch_model.py` | Shared constants, preset parsing, candidate response writing, report/result parsing, scoring, and startup preflight helpers. |
| `tools/launch_parameter_search.py` | Runs simulator-backed searches over release theta, impact theta, strike direction, radius, and face angle. |
| `tools/launch_search_heatmap.py` | Plots direction/face-angle heatmaps from launch-search CSVs. |
| `tools/strike_angle_scan.py` | Plots time-versus-strike-angle maps and contact modes for a fixed launch setup. |
| `tools/score_paired_impulse_grid.py` | Analytic, no-solver score grid for paired face impulses. |
| `tools/show_paired_impulse_geometry.py` | 3D visual diagnostic for one paired face-impulse setup. |
| `tools/pendulum_rod.py` | Physical rod-pendulum helper and standalone impact animation. |

## Fixed Output Names

The output names are defined in `model2/disk_data.f90`:

```fortran
cresf = 'result.txt'
coutf = 'report.txt'
cgraf = 'animat.txt'
```

Changing output location or run naming should start there, then update
`run.bat` and the viewer launch path.
