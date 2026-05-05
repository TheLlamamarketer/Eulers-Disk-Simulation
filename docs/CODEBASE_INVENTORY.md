# Euler Disk Codebase Inventory

This inventory classifies the current `test2` folder without moving anything.
The goal is to make the modernization path obvious while keeping the old
material available for reference.

## Provenance Notes

Codex-added modernization files are useful, but they are not original 2003
source material:

- `run.bat`
- `edisk_gl_viewer.c`
- `VIEWER_NOTES.md`
- `docs/*`
- `archive/README.md`
- all `.exe` files
- copied runtime DLLs such as `libfreeglut__.dll`
- everything under `build_gfortran/`

Treat all `.exe` files as binary artifacts or external references, never as
source. If an executable was supplied with the old program, keep it only as a
comparison/reference binary.

## Active Modern Path

These files are currently important for running or rebuilding the useful
program.

| Area | Files | Role |
| --- | --- | --- |
| Workflow | `run.bat` | Codex-added helper and best current entry point. Builds the headless simulation and native OpenGL viewer, then opens `animat.txt`. |
| Physics model | `model2/disk.f90`, `model2/disk0.f90`, `model2/disk_data.f90`, `model2/cdata.f90`, `model2/prop.f` | Core disk geometry, contact force, rolling/sliding dynamics, inertia calculation, and shared state. |
| Simulation driver | `model2/main.f90`, `model2/input.f90`, `model2/integ.f90`, `model2/solout.f90`, `model2/post.f90`, `model2/ztime.f90`, `zeroin.f` | Command-line simulation setup, ODE integration, event/mode handling, result output, and conversion to animation data. |
| Console UI | `screen/*.f90` | Legacy prompt/input helpers. Still needed by interactive `input.f90`, but replaceable later. |
| ODE vendor code | `hairer/cdopri.for`, `hairer/contd5.for`, `hairer/contd8.for`, `hairer/dop853.for`, `hairer/dopcor.for`, `hairer/dopri5.for`, `hairer/dp86co.for`, `hairer/hinit.for` | Active Hairer/Wanner DOPRI5/DOP853 solver implementation used by `integ.f90`. |
| Viewer | `edisk_gl_viewer.c`, `VIEWER_NOTES.md` | Codex-added modern native OpenGL viewer for `animat.txt`. |

## Useful Reference, But Not Active

These are valuable for understanding history or confirming behavior, but they
do not need to stay in the active working path.

| Area | Files | Why keep |
| --- | --- | --- |
| Original Fortran OpenGL viewer | `archive/legacy_fortran_opengl/graphics/*.f90` | Shows the original f90GL/GLUT transformation order, controls, disk drawing, and animation logic. Useful as reference, not needed for current build. |
| Packaged/reference app folder | `archive/full_app_reference/Full App/` | Binary/data reference only. Any `.exe` inside is not source and should not drive the modernization except for behavioral comparison. |
| Visual Studio 6 project | `archive/visual_studio_6/test2.dsp`, `archive/visual_studio_6/test2.dsw` | Historical build recipe and file list for the original Compaq Visual Fortran project. |

## Generated Or Local Build Products

These should not be treated as source. They can be regenerated.

| Files | Notes |
| --- | --- |
| `build_gfortran/` | Object files, `.mod` files, rebuilt executables, copied DLLs. Safe to delete and regenerate with `run.bat`. |
| `runs/last_snapshot/animat.txt`, `runs/last_snapshot/result.txt`, `runs/last_snapshot/report.txt` | Preserved output snapshot from before cleanup. New simulations write fresh files in the repo root. |
| `generated/bin/*.exe`, `generated/bin/*.dll` | Root-level built/copied artifacts moved out of the active source area. Source for the modern viewer is `edisk_gl_viewer.c`; source for the simulation is Fortran. |
| `archive/visual_studio_build_output/Debug/` | Old Visual Studio output folder. Currently not part of the modern build. |

## Archive Candidates

These are likely safe to move into an archive folder after a quick preservation
pass.

| Files | Suggested archive bucket | Reason |
| --- | --- | --- |
| `archive/visual_studio_6/` | Already moved | IDE/browser/project files. Historical only. |
| `archive/legacy_fortran_opengl/graphics/` | Already moved | Superseded by `edisk_gl_viewer.c`; still useful as reference. |
| `archive/full_app_reference/Full App/` | Already moved | Binary/reference package, not source. |
| `archive/vendor_unused/` | Already moved | Unused Hairer duplicates/examples. Preserve as vendor leftovers. |
| `archive/legacy_output_routines/xsolout.f90` | Already moved | Alternate/old output routine; not used by the current build path. |

## Do Not Archive Yet

Keep these until the modern replacement exists:

- `screen/*.f90`: needed for interactive input.
- Active `hairer/*.for` files listed above: needed by the integrator.
- `model2/input.f90`: currently owns defaults and prompt flow.
- `model2/solout.f90`: currently owns mode transitions and result file output.
