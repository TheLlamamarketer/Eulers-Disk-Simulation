# Modernization Plan

The current code now has a working modern-ish path:

```text
run.bat
  -> builds/runs headless Fortran physics
  -> writes animat.txt/result.txt/report.txt
  -> builds/runs edisk_gl_viewer.c under build_gfortran/
```

The next goal is to reduce surprise: separate source, vendor code, generated
outputs, and archived historical material.

`run.bat` and `edisk_gl_viewer.c` are Codex-added modernization helpers. They
are useful active files, but they are not original project evidence. All `.exe`
files should be treated as generated or external binary artifacts, not source.

## Target Layout

This is the suggested end state.

```text
src/
  physics/
    disk.f90
    disk0.f90
    disk_data.f90
    cdata.f90
    prop.f
  simulation/
    main.f90
    input.f90
    integ.f90
    solout.f90
    post.f90
    ztime.f90
    zeroin.f
  ui_legacy/
    screen/*.f90

vendor/
  hairer/
    active DOPRI5/DOP853 files

tools/
  viewer_opengl/
    edisk_gl_viewer.c

runs/
  current/
    animat.txt
    result.txt
    report.txt

build/
  gfortran/

archive/
  visual_studio_6/
  legacy_fortran_opengl/
  full_app_reference/
  visual_studio_build_output/
  vendor_unused/
  legacy_output_routines/

docs/
```

## Cleanup Phases

### Phase 1: Document And Freeze

- Keep Codex-added `run.bat` as the current known-good entry point.
- Keep current source locations until the build script is ready to follow moved files.
- Use `docs/CODEBASE_INVENTORY.md` as the authority for active vs archive candidates.

### Phase 2: Move Pure Archive Material

Completed. These files were moved because they are not referenced by `run.bat`:

- Visual Studio browser/options/log files.
- `archive/full_app_reference/Full App/` binary/data reference.
- Legacy Fortran OpenGL viewer from `graphics/`.
- Unused Hairer duplicates/examples.
- `model2/xsolout.f90`.

After this phase, `run.bat` should still build and run unchanged.

### Phase 3: Separate Generated Outputs

Partially done. The root-level generated outputs that existed during cleanup
were moved to `runs/last_snapshot/`.

The old Fortran still writes fixed filenames in the working directory. Modernize this
by either:

- running the simulation from `runs/current/`, or
- changing `disk_data.f90` to put outputs under a configured output directory.

The second option is cleaner, but it touches Fortran source.

### Phase 4: Replace Legacy Console Input

The `screen/*.f90` modules exist mostly to support prompts and expression
parsing. A modern path should add a simple config file, for example:

```text
radius = 0.08
height = 0.0128
theta0 = 0.1
tend = 100.0
tprint = 0.0005
precision = high
```

Then `input.f90` can load defaults from config and `screen/*.f90` can move to
the archive.

### Phase 5: Make Physics Testable

Split the simulation into:

- pure dynamics functions,
- integrator wrapper,
- output writer,
- CLI/config layer.

That makes it possible to compare short benchmark runs against preserved
`result.txt`/`animat.txt` files.

## First Physical Move Completed

The first real move was:

```text
archive/
  visual_studio_6/
    test2.ncb
    test2.opt
    test2.plg

  vendor_unused/
    hairer/dopri5.f
    hairer/dop853.f
    hairer/zzz000.for
    hairer/fort.11

  legacy_output_routines/
    model2/xsolout.f90

  legacy_fortran_opengl/
    graphics/

  full_app_reference/
    Full App/

  visual_studio_build_output/
    Debug/

runs/
  last_snapshot/
    animat.txt
    result.txt
    report.txt

generated/
  bin/
    edisk_gl_viewer.exe
    libfreeglut__.dll
```

Those files are not used by the active `run.bat` workflow.
