# Physics Model

This document describes the model currently implemented by the Fortran code.

## Scope

The simulation is a rigid-body Euler disk model with one contact point on a
horizontal plane. It switches between two motion modes:

| Mode | State |
| --- | --- |
| Sliding | 10 variables, including center velocity. |
| Rolling | 8 variables, with no-slip velocity constraints. |

The contact model includes Coulomb friction and dissipative rolling/boring
moments. It is useful for exploring rolling and sliding behavior, but it is not
a compliant contact, deformation, acoustic, or finite-area contact model.

## Geometry And Mass

The input geometry is:

- disk radius `r`
- disk height `h`
- fillet radius `rho`
- material density `disk_density`

`model2/disk_data.f90` computes an approximate rounded-disk volume and derives:

```text
mass = density * disk_volume(radius, height, fillet)
```

`model2/prop.f` computes the radii of gyration `xk12` and `xk22`. The energy
calculations and pendulum impact initializer use the derived mass together with
those radii of gyration.

## Resistance Inputs

The user-facing rolling and boring resistance inputs are dimensionless ratios:

```text
rolling_x_over_R
rolling_y_over_R
boring_z_over_R
```

`update_disk_properties()` converts them into the meter-valued contact moment
arms used internally:

```text
xmurx = rolling_x_over_R * radius
xmury = rolling_y_over_R * radius
xmurz = boring_z_over_R  * radius
```

This keeps the loss parameters tied to disk size when radius changes.

## Near-Vertical Regularization

A perfectly vertical finite cylinder has a line contact, not a unique point
contact. The original point-contact model is therefore ambiguous near
`theta = 0`.

The current code smooths the contact geometry within:

```fortran
theta_line_smooth = 2.0e-2_8
```

This is a practical regularization so vertical or near-vertical launches do not
immediately produce artificial contact jumps. It is not a replacement for a full
line-contact model.

## Near-Flat Stop

The Euler-angle representation becomes ill-conditioned near the flat state
`theta = pi/2`, and the point-contact assumption also becomes questionable.

The current stop tolerance is:

```fortran
theta_flat_stop_tol = 2.0e-4_8
```

The viewer hides the contact marker/path close to the flat state because a nearly
flat disk does not have a stable single visible contact point in this model.

## Rolling And Sliding Events

`model2/solout.f90` monitors dense output from DOPRI/DOP853 to detect:

- sliding-to-rolling transitions when slip speed reaches a local minimum near
  zero,
- rolling-to-sliding transitions when static friction can no longer enforce the
  rolling constraint,
- stop conditions near the flat state or very low energy.

`model2/ztime.f90` provides the event-time polynomial used by this callback, and
`zeroin.f` is used for scalar event root finding.

When rolling breaks loose, the new sliding segment is seeded with a tiny slip
velocity opposite the rolling friction force. This gives Coulomb friction a
defined direction without creating a visible impulse.

Sliding friction is regularized over a small slip speed,
`slip_regularization = 1.0e-3 m/s`. For ordinary strike slip speeds this is
negligible, but it prevents the ideal Coulomb direction `v_slip / |v_slip|`
from becoming numerically singular as contact relocks. Real finite contact
patches also pass through a small micro-slip/deformation regime instead of an
instantaneous mathematical discontinuity.

## Pendulum Strike Initializer

`model2/input.f90` supports three launch modes:

| Mode | Meaning |
| --- | --- |
| `0` | Manual angular and center velocity inputs. |
| `1` | Simple pendulum strike initializer. |
| `2` | Mirrored double-pendulum strike initializer. |

The pendulum strike mode computes a launch impulse from pendulum mass, length,
release angle, restitution, efficiency, strike direction, and strike point:

```text
v_pendulum = sqrt(2 g L (1 - cos(release_angle)))
J          = efficiency * (1 + restitution) * v_pendulum / effective_mass_den
omega+     = omega- + I^-1 (r_contact x J n)
```

The strike point is selected on the disk surface:

| Surface | Inputs |
| --- | --- |
| `0=rim` | rim angle and axial offset through the thickness |
| `1=+face` | face radius and face angle |
| `2=-face` | face radius and face angle |

Double pendulum mode reuses the first strike radius for pendulum 2, but gives the
second strike its own disk-plane angle. The interactive default is the first
strike angle mirrored as `180 degrees - angle`, so a strike at angle 30 and
radius `a` pairs with a second strike at angle 150 and radius `a`. The second
strike direction also defaults to the first direction plus 180 degrees, which
makes identical paired pendulums add a rotational couple instead of cancelling.
For face strikes,
`+face` still pairs with `-face` and vice versa; rim strikes keep the same axial
offset. The two pendulums have independent mass, length, release angle,
restitution, efficiency, strike direction, and second disk-angle inputs. Their
computed impulses are added before the initial angular velocity and optional
free-body center velocity are assigned.

For symmetric face strikes, the direction pairing matters. If the first strike
uses direction `d`, the physically useful mirrored second direction is
`d + 180 degrees`, not the small positive mirror angle. For example,
`349 degrees` paired with `169 degrees` nearly cancels the net horizontal
linear impulse while adding disk-axis torque. Pairing `349 degrees` with
`11 degrees` instead cancels much of the disk-axis torque and adds a tipping
torque, launching an orbiting/flopping motion rather than a long-lived spin.

Post-impact center velocity has three modes:

| Mode | Meaning |
| --- | --- |
| `0=free` | Center velocity receives the free-body impulse `J / mass`. |
| `1=supported` | The strike creates angular velocity but no full center impulse. |
| `2=rolling` | Center velocity is set to match instantaneous no-slip rolling. |

`report.txt` records the generated strike point or strike points, pendulum
speed, impulse, initial slip speed, energy split, and wobble/axis-spin
diagnostics. In this model the disk symmetry-axis spin is the `omega2`
component; large `omega1`/`omega3` compared with `omega2` means the launch is
mostly a tipping/orbiting impulse rather than a long-lived Euler-disk spin.

For the mirrored face-strike configuration with contact points at disk-plane
angles 90 and 270 degrees, the cleanest paired strike direction is 0 and 180
degrees. The horizontal impulses cancel while their `omega2` torques add. Small
direction offsets can look useful early in a run, but they add wobble torque and
can drive late rolling/sliding chatter or step-size failure. Increasing the face
strike radius reduces the unavoidable finite-thickness wobble contribution.

`tools/sweep_double_pendulum.py` runs bounded sweeps over pendulum mass, release
angle, strike direction, and face radius while preserving `theta=0`, free
post-impact center velocity, the mirrored upper/lower impact points, and the
current friction/resistance values from `init/double_pendulum.responses`.
