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

## Pendulum Strike Initializer

`model2/input.f90` supports two launch modes:

| Mode | Meaning |
| --- | --- |
| `0` | Manual angular and center velocity inputs. |
| `1` | Simple pendulum strike initializer. |

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

Post-impact center velocity has three modes:

| Mode | Meaning |
| --- | --- |
| `0=free` | Center velocity receives the free-body impulse `J / mass`. |
| `1=supported` | The strike creates angular velocity but no full center impulse. |
| `2=rolling` | Center velocity is set to match instantaneous no-slip rolling. |

`report.txt` records the generated strike point, pendulum speed, impulse,
initial slip speed, energy split, and tip/spin diagnostics.
