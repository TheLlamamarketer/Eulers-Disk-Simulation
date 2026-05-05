# Cleanup Log

## 2026-05-02

Moved non-active legacy/reference material out of the source root:

- `test2.dsp`, `test2.dsw`, `test2.ncb`, `test2.opt`, `test2.plg`
  -> `archive/visual_studio_6/`
- `graphics/`
  -> `archive/legacy_fortran_opengl/graphics/`
- `Full App/`
  -> `archive/full_app_reference/Full App/`
- `Debug/`
  -> `archive/visual_studio_build_output/Debug/`
- `hairer/dopri5.f`, `hairer/dop853.f`, `hairer/zzz000.for`, `hairer/fort.11`
  -> `archive/vendor_unused/`
- `model2/xsolout.f90`
  -> `archive/legacy_output_routines/xsolout.f90`

Moved generated root-level files:

- `animat.txt`, `result.txt`, `report.txt`
  -> `runs/last_snapshot/`
- `edisk_gl_viewer.exe`, `libfreeglut__.dll`
  -> `generated/bin/`

Verification performed:

- Rebuilt `build_gfortran/edisk_gl_viewer.exe` from `edisk_gl_viewer.c`.
- Parsed `runs/last_snapshot/animat.txt` with the rebuilt viewer using `--info`.
- Checked that all active source paths referenced by `run.bat` still exist.

No active Fortran physics, active Hairer solver files, or console UI files were moved.
