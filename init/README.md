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
| `double_pendulum.responses` | Two-pendulum launch with a configurable second disk angle. |
| `pendulum_high_loss.responses` | Vertical disk struck by a pendulum with stronger losses and supported center velocity. |

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
Pendulum mass [kg]
Pendulum length [m]
Pendulum release angle [deg]
Restitution coefficient
Impact efficiency
Strike direction angle [deg]
Strike surface: 0=rim, 1=+face, 2=-face
Strike radius or rim angle, depending on surface
Strike face angle or rim axial offset, depending on surface
Post-impact center velocity: 0=free, 1=supported, 2=rolling
```

Double pendulum strike mode uses the first strike geometry as the shared setup,
then appends the configurable values for the second pendulum. The second strike
uses the same radius and its own disk-plane angle, which defaults interactively
to 180 degrees minus the first strike angle. The second strike direction
defaults to the first strike direction plus 180 degrees:

```text
Initial condition mode: 2
Pendulum 1 mass [kg]
Pendulum 1 length [m]
Pendulum 1 release angle [deg]
Pendulum 1 restitution coefficient
Pendulum 1 impact efficiency
Pendulum 1 strike direction angle [deg]
Strike surface for pendulum 1: 0=rim, 1=+face, 2=-face
Strike radius or rim angle, depending on surface
Strike face angle or rim axial offset, depending on surface
Post-impact center velocity: 0=free, 1=supported, 2=rolling
Pendulum 2 mass [kg]
Pendulum 2 length [m]
Pendulum 2 release angle [deg]
Pendulum 2 restitution coefficient
Pendulum 2 impact efficiency
Pendulum 2 strike direction angle [deg]
Strike 2 disk angle [deg]
```

For face strikes, the paired face is still complementary: `+face` becomes
`-face`, and `-face` becomes `+face`. Rim strikes keep the same axial offset.

The physics meaning of these values is described in `../docs/PHYSICS_MODEL.md`.

```text
Große Disk 1471 g
Mittlere Disk 620g
Kleine Disk 473,8g (Feinwaage)
The Following Disks are available for testing:
- W=473,8g, R=0.04m, H=0.012m, V=6.031e-5m^3, rho=7855kg/m^3
- W=620g, R=0.05m, H=0.01m, V=7.854e-5m^3, rho=7894kg/m^3
- W=1471g, R=0.08m, H=0.0105m, V=21.112e-5m^3, rho=6968kg/m^3
```
