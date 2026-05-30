# Initial Condition Presets

Files in this directory are response files for the Fortran prompts in
`model2/input.f90`.

Run a preset with:

```bat
.\run.bat init\manual.responses
```

`run.bat` removes blank lines and everything after `#`, writes the cleaned values
to `build_gfortran/input_responses.tmp`, then feeds those values to the
simulation.

## Available Presets

| File | Purpose |
| --- | --- |
| `manual.responses` | Manual spin launch for a larger 80 mm disk. Good everyday baseline. |
| `original.responses` | Original reference geometry and launch, with angle inputs converted to degrees. |
| `pendulum.responses` | Side-strike pendulum launch with low rolling/boring losses. |
| `double_pendulum.responses` | Mirrored two-pendulum launch. The second pendulum is derived from the first. |

## Editing A Preset

Copy an existing `.responses` file and keep the prompt order unchanged.

Comments are allowed:

```text
0.08     # Disk radius [m]
6        # Initial X rotation theta [deg]
0        # Initial condition mode: 0=manual, 1=pendulum strike, 2=double pendulum strike
```

Manual launch mode uses this prompt order:

```text
Disk radius [m]
Disk height [m]
Disk fillet radius [m]
Disk density [kg/m^3]
Initial Z rotation psi [deg]
Initial X rotation theta [deg]
Initial Y rotation phi [deg]
Initial condition mode: 0
Initial Omega1 [rad/s]
Initial Omega2 [rad/s]
Initial Omega3 [rad/s]
Initial center velocity Vx [m/s]
Initial center velocity Vy [m/s]
Static friction coefficient
Dynamic friction coefficient
Rolling resistance x/R
Rolling resistance y/R
Boring/spin resistance z/R
End time [s]
Print time step [s]
Relative tolerance
Absolute tolerance
```

Pendulum strike mode replaces the manual velocity lines with:

```text
Initial condition mode: 1
Physical pendulum release theta [deg]
Physical pendulum impact theta [deg]
Restitution coefficient
Impact efficiency
Strike direction angle [deg]
Strike surface: 0=rim, 1=+face, 2=-face
Strike radius or rim angle, depending on surface
Strike face angle or rim axial offset, depending on surface
Post-impact center velocity: 0=free, 1=supported, 2=rolling
```

Double pendulum strike mode uses one rod-pendulum setup, then mirrors it in
code. The second pendulum uses the same release theta, impact theta,
restitution, and efficiency. Its strike direction is `direction + 180 degrees`,
and its disk-plane angle is `angle + 180 degrees`:

```text
Initial condition mode: 2
Pendulum 1 release theta [deg]
Pendulum 1 impact theta [deg]
Pendulum 1 restitution coefficient
Pendulum 1 impact efficiency
Pendulum 1 strike direction angle [deg]
Strike surface for pendulum 1: 0=rim, 1=+face, 2=-face
Strike radius or rim angle, depending on surface
Strike face angle or rim axial offset, depending on surface
Post-impact center velocity: 0=free, 1=supported, 2=rolling
```

For face strikes, the paired face is still complementary: `+face` becomes
`-face`, and `-face` becomes `+face`. Rim strikes keep the same axial offset.

The physics meaning of these values is described in `../docs/PHYSICS_MODEL.md`.

## Measured Test Disks

| Label | Mass | Radius | Height | Volume | Density |
| --- | ---: | ---: | ---: | ---: | ---: |
| Small | 473.8 g | 0.04 m | 0.012 m | 6.031e-5 m^3 | 7855 kg/m^3 |
| Medium | 620 g | 0.05 m | 0.01 m | 7.854e-5 m^3 | 7894 kg/m^3 |
| Large | 1471 g | 0.08 m | 0.0105 m | 21.112e-5 m^3 | 6968 kg/m^3 |
