# Initial Condition Files

Run a preset with:

```bat
.\run.bat init\pendulum.responses
```

These files are prompt-response files for the old Fortran console input. Each
non-comment line contains one answer. `run.bat` strips blank lines and anything
after `#`, then feeds only the remaining values to the simulation.

This means values can stay readable:

```text
1717.47 # Disk density [kg/m^3]
1.1459  # Initial X rotation theta [deg]
1       # Initial condition mode: 0=manual, 1=pendulum strike
```

When adding a new preset, copy an existing `.responses` file and keep the prompt
order unchanged.

## Material And Size

Mass is now computed from the disk geometry and density:

```text
mass = density * disk_volume
```

The built-in default density is `7792.2775 kg/m^3`, which preserves the old
`0.4387 kg` mass for the original reference disk:

```text
R = 0.03755 m, h = 0.0128 m, fillet = 0.002 m
```

The rolling/boring resistance inputs are dimensionless material-scale ratios,
not raw meter lengths. The simulation converts them to the meter-valued contact
moment arms used internally:

```text
rolling_x [m] = rolling_x_over_R * disk_radius
rolling_y [m] = rolling_y_over_R * disk_radius
boring_z  [m] = boring_z_over_R  * disk_radius
```

This means changing disk radius automatically updates mass and loss lengths
instead of reusing constants from the original Euler's disk example.

For pendulum strikes, the strike point is now chosen on the disk surface:

- `0=rim` asks for a rim angle in degrees and an axial offset through the
  thickness.
- `1=+face` and `2=-face` ask for a face radius and face angle in degrees.
- The generated body-frame point is written to `report.txt` as
  `Strike point body [m]`.

The post-impact center velocity mode controls how much translational impulse the
simple strike model leaves in the disk:

- `0=free`: free-body impact, with center velocity `J / disk_mass`.
- `1=supported`: table/launcher supported impact, angular impulse only.
- `2=rolling`: angular impulse plus a center velocity compatible with no-slip
  rolling at the first instant.

## Vertical Pendulum Strike

`init/pendulum_high_loss.responses` keeps the disk vertical and stationary
before impact. The pendulum supplies both the spin and the initial tipping
angular velocity. The important geometry is:

```text
Initial theta        = 0 deg
Pendulum mass       = 0.5 kg
Release angle       = 43.25 deg
Strike direction    = 270 deg
Strike face radius  = 0.045 m
Strike face angle   = 16 deg
Center velocity     = supported
```

The nonzero face angle is intentional. With an exactly vertical disk, a pure
`Omega3` launch would just spin upright. The offset strike creates a controlled
`Omega1` tipping component so the disk leaves the vertical state and rises
toward `theta = 90 deg`.

## Side-Strike Face Angle

For a `Strike direction angle = 90 deg` face strike, the face angle is the main
side-flop control. The approximate launch ratio is:

```text
tipping impulse / spin impulse ~= tan(face_angle)
```

Positive and negative angles mirror the flop direction. Near `0 deg` gives
mostly spin for that side-strike geometry. Larger magnitudes add tipping:

```text
0 deg       clean spin, almost no tip
5-10 deg    spin-dominant with a small wobble
15-30 deg   strong flop toward flat contact
35+ deg     usually near-flat chatter or solver failure
```

The exact boundary depends on disk radius, strike radius, release angle, losses,
and the strike direction. `report.txt` prints `Strike torque tip/spin` and
`Initial omega tip/spin` so the launch can be checked numerically.
