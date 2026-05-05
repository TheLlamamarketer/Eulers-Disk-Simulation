# Physics Notes

## Current Model

The Fortran physics still uses the original rigid-body, single-contact-point
model with two modes:

- `sliding`: 10 state variables, including center velocity.
- `rolling`: 8 state variables, with no-slip velocity constraints.

The model uses Coulomb friction and a dissipative contact moment. It is useful
for studying rolling/sliding behavior, but it is not a full compliant contact,
acoustic, or deformation model.

## Recent Accuracy/Stability Tweaks

### Event-Time Polynomial

`model2/ztime.f90` now evaluates the quadratic event polynomial correctly with
Horner's rule. The previous loop included the highest-order coefficient twice,
which could shift rolling/sliding and stop-event times.

### Sliding To Rolling Transition

`model2/solout.f90` no longer extrapolates the slip-speed zero into the future.
When the slip speed falls below tolerance, it estimates the local quadratic
minimum within the last output interval and restarts the integrator there.

`model2/integ.f90` also refreshes the event-time state before calling
DOPRI/DOP853 again after a rolling-to-sliding mode switch. Without this handoff,
the sliding segment could restart from the wrong dense-output point and the
animation could show a visible jump. Sliding-to-rolling restarts keep the older
minimal handoff because that event is more numerically delicate in this model.
When rolling breaks loose, the new sliding segment is seeded with a tiny slip
velocity opposite the rolling friction force, giving Coulomb friction a defined
direction without creating a visible impulse.

### Near-Vertical Line Contact

`model2/disk0.f90` now regularizes the contact point inside a small angle
around `theta = 0`. The original model has a true ambiguity there because a
perfectly vertical finite cylinder has a line contact, not a unique point
contact. The old code treated this as a "slap" event and toggled rolling/sliding
mode, which could look like a nonphysical bounce.

The knob is:

```fortran
theta_line_smooth = 2.0e-2_8
```

This is a modeling regularization, not a first-principles contact model. It is
intended to let near-vertical launch tests behave smoothly until a better
pendulum/impact initializer and compliant-contact model exist.

### Near-Flat Behavior

The model stops only very close to the Euler-angle singularity at
`theta = pi/2`:

```fortran
theta_flat_stop_tol = 2.0e-4_8
```

The single-point rigid-body model is already questionable extremely close to the
flat state, and the Euler-angle rates become ill-conditioned there. The viewer
therefore hides the contact-point marker/path near the flat state instead of
stopping the disk early; a nearly flat disk does not have a stable single
contact point in this simplified model.

### Viewer Interpolation

`edisk_gl_viewer.c` now linearly interpolates frames by simulation time instead
of drawing only the nearest saved sample. This reduces late-time visual jumping,
though high spin rates can still alias visually if playback is too fast.

## Material And Geometry Scaling

The original code used a fixed disk mass (`0.4387 kg`) and raw resistance
lengths tuned for the reference Euler disk (`R = 0.03755 m`, `h = 0.0128 m`,
`fillet = 0.002 m`). The input layer now derives mass from the selected
geometry and density:

```text
mass = density * disk_volume
```

The moment of inertia values `xk12` and `xk22` are still radii of gyration
computed by `prop.f`; multiplying by the derived mass gives the actual moments
used in energies and pendulum impact calculations.

Rolling and boring resistance inputs are now dimensionless ratios relative to
disk radius:

```text
xmurx = rolling_x_over_R * R
xmury = rolling_y_over_R * R
xmurz = boring_z_over_R  * R
```

The equations still use the meter-valued `xmur*` contact moment arms internally,
but presets can keep material-like ratios when changing disk size.

The default density (`7792.2775 kg/m^3`) preserves the old `0.4387 kg` mass for
the original reference geometry.

## Pendulum Strike Initializer

`model2/input.f90` now has an optional initial-condition mode:

```text
Initial condition mode [0=manual,1=strike]
```

Mode `0` keeps the original manual angular/linear velocity prompts. Mode `1`
uses a simple pendulum strike model to compute the disk's initial center
velocity and angular velocity from an impact impulse:

```text
v_pendulum = sqrt(2 g L (1 - cos(beta)))
J          = efficiency * (1 + restitution) * v_pendulum / effective_mass_den
v_C+     = v_C- + J n / m
omega+   = omega- + I^-1 (r_contact x J n)
```

The current first version assumes the disk is initially at rest before impact.
The strike direction is a horizontal world-frame angle. The strike target is now
chosen on the disk surface rather than as raw body-frame coordinates:

```text
Strike surface [0=rim,1=+face,2=-face]
```

Rim strikes ask for a rim angle and thickness offset. Face strikes ask for a
face radius and angle. This prevents hidden "inside the disk" targets while
still allowing either face or the outside rim to be selected reproducibly.
Interactive/preset angle inputs are in degrees for readability; the solver
still converts and stores these angles internally in radians.

For a horizontal `90 deg` side strike, the strike face angle also sets the
approximate side-flop/spin split:

```text
tipping impulse / spin impulse ~= tan(face_angle)
```

Small angles are spin-dominant for that side-strike geometry. Larger magnitudes
add a side-flop component and can drive the disk nearly flat, producing
rolling/sliding chatter at the Euler-angle/contact singularity. The report
prints both `Strike torque tip/spin` and `Initial omega tip/spin` as launch
diagnostics.

The high-loss pendulum preset keeps the disk vertical and stationary before the
hit. It therefore cannot use the pure-spin manual launch directly: an exactly
vertical disk with only `Omega3` would spin upright. Instead it uses a
`270 deg` side strike with a `16 deg` face offset, producing negative
`Omega3` plus a controlled `Omega1` tipping component.

The initializer also asks how to treat the center velocity after impact:

```text
Post-impact center velocity [0=free,1=supported,2=rolling]
```

Mode `0` keeps the original free-body impulse estimate. Mode `1` is a simple
table-supported approximation: the strike creates angular velocity, but the
center is not given the pendulum's full translational impulse. Mode `2` sets the
center velocity compatible with instantaneous no-slip rolling. The report now
records the selected modes, generated body-frame strike point, pendulum speed,
impact impulse, initial contact slip speed, and initial energy split.

The original response values use relatively large rolling/boring resistance.
Those losses make the disk collapse sooner even without air resistance.
`init/pendulum.responses` keeps a lower-loss side-strike example for exploratory
runs; `init/pendulum_high_loss.responses` keeps the high-loss scale and the
vertical stationary pre-impact constraint.

The legacy console calculator in `screen/mcalc.f90` was also adjusted so long
decimal inputs are accumulated as `real(8)` values instead of overflowing an
integer scratch variable. Expression inputs are still supported.

This is intentionally modest: it gives a reproducible bridge from a physical
launcher idea to the existing rigid-body solver without adding a full compliant
impact/contact model yet.
