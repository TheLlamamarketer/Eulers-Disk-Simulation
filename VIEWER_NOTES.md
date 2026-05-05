# Euler Disk Viewers

## Native OpenGL Viewer

Run:

```powershell
.\build_gfortran\edisk_gl_viewer.exe animat.txt
```

Or use the animation data that came with the original app:

```powershell
.\build_gfortran\edisk_gl_viewer.exe "archive\full_app_reference\Full App\animat.txt"
```

Or view the output snapshot preserved during cleanup:

```powershell
.\build_gfortran\edisk_gl_viewer.exe "runs\last_snapshot\animat.txt"
```

Controls:

- Left mouse drag: orbit camera, including below the disk
- Middle or right mouse drag: pan
- Mouse wheel: zoom
- Space: play or pause
- `r`: restart
- `+` / `-`: speed up or slow down
- `1`, `2`, `5`, `0`: set speed to 1x, 2x, 5x, 10x
- `g`: toggle grid
- `p`: toggle contact path
- `t`: toggle text overlay
- `Esc` or `q`: quit

The viewer reads the same `animat.txt` file as the original 2003 GLUT app. It uses a real OpenGL depth buffer and draws a rounded-edge disk mesh, so underside views and edge curvature are handled properly. Disk orientation is interpolated with quaternions, which avoids visible flips when the saved Euler angles jump branches near the flat-disk singularity.

The blue and red arrows are fixed to the disk body and rotate with it. The green contact path is drawn just below the ground plane so it does not cut through the disk at the contact point.

## Simulation Workflow

The physics simulation is the headless Fortran executable:

```powershell
.\build_gfortran\edisk_headless.exe
```

It asks for disk and friction parameters, writes `result.txt`, `report.txt`, and `animat.txt`, then exits.

For the combined workflow:

```powershell
.\run_sim_and_view.bat
```

This runs the simulation interactively and opens the OpenGL viewer with the newly generated `animat.txt`.

To run with all default simulation inputs:

```powershell
.\run_defaults_and_view.bat
```

## Rebuild

If Strawberry MinGW is installed:

```powershell
.\run.bat
```

`run.bat` builds the viewer into `build_gfortran/` and copies `libfreeglut__.dll`
there when available.

## Browser Viewer

`edisk_viewer.html` is still available as a dependency-free fallback, but it is only a 2D canvas projection. The native OpenGL viewer is the better option for inspecting the disk from arbitrary 3D angles.
