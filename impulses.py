import numpy as np
import matplotlib.pyplot as plt

from impulses_sweep import startup_eval


def draw_rotation_arc(
    ax,
    axis_vec,
    center,
    radius,
    color,
    offset_deg=30.0,
    arc_length_deg=30.0,
    arrow_scale=0.85,
    head_ratio=0.8,
    n_points=12,
):
    """Draw small curved arc segments with arrowheads."""

    nrm = np.linalg.norm(axis_vec)
    if nrm == 0:
        return
    u = axis_vec / nrm
    ref = np.array([1.0, 0.0, 0.0])
    if abs(np.dot(u, ref)) > 0.9:
        ref = np.array([0.0, 1.0, 0.0])
    a = np.cross(u, ref)
    a /= np.linalg.norm(a)
    b = np.cross(u, a)

    off = np.radians(offset_deg)
    half = np.radians(arc_length_deg) / 2.0
    center_angles = [off, off + np.pi]

    for cang in center_angles:
        th = np.linspace(cang - half, cang + half, n_points)
        pts = center + radius * (np.cos(th)[:, None] * a + np.sin(th)[:, None] * b)
        ax.plot3D(pts[:, 0], pts[:, 1], pts[:, 2], color=color, linewidth=2.0)
        end = pts[-1]
        tand = -np.sin(th[-1]) * a + np.cos(th[-1]) * b
        tand /= np.linalg.norm(tand)
        ax.quiver(
            end[0],
            end[1],
            end[2],
            tand[0],
            tand[1],
            tand[2],
            length=radius * arrow_scale,
            color=color,
            linewidth=2.0,
            arrow_length_ratio=head_ratio,
        )


r = 0.05
d = 0.01
rho = 0.001
h = d / 2.0

# phip is positive-clockwise here; phi_p=70 deg matches the simulator's
# strike direction of -70 deg.
strike_impulse = 0.139
phi_p = np.radians(10)
phi1 = np.radians(140)
phi2 = phi1 + np.radians(180)
face_radius = 0.045
r1 = face_radius
r2 = face_radius

p = strike_impulse * np.array([np.cos(phi_p), -np.sin(phi_p), 0.0])
a1 = np.array([r1 * np.cos(phi1), h, r1 * np.sin(phi1)])
a2 = np.array([r2 * np.cos(phi2), -h, r2 * np.sin(phi2)])
a = a1 - a2

result = startup_eval(
    phi1,
    phi_p,
    r=r,
    d=d,
    rho=rho,
    r_frac=face_radius / r,
    p_mag=strike_impulse,
)
omega = result["omega"]
a_g = result["ag"]
v_c = result["vc"]

print("omega:", omega)
print("wobble/axis:", result["nutation_ratio"])
print("v_c:", v_c)
print("tangential slip speed:", result["slip_speed"])
print("vertical contact speed:", result["vertical_speed"])
print(
    "min normal/g:",
    result["min_normal_g"],
    "at t:",
    result["min_normal_time"],
    "theta:",
    result["min_normal_theta"],
    "safe:",
    result["safe_contact"],
)
print("normal margin/g:", result["normal_margin_g"])
print("contact state:", result["contact_state"], "(2 means sliding, not lift-off)")

theta = np.linspace(0, 2 * np.pi, 24)
y = np.linspace(-h, h, 2)
theta, y = np.meshgrid(theta, y)

x = r * np.cos(theta)
z = r * np.sin(theta)

r_cap, theta_cap = np.meshgrid(np.linspace(0, r, 20), theta)

cap_x = r_cap * np.cos(theta_cap)
cap_z = r_cap * np.sin(theta_cap)

fact = np.linalg.norm(omega) / 0.03
fact_p = np.linalg.norm(p) / 0.03

fig = plt.figure()
ax = fig.add_subplot(111, projection="3d")
ax.scatter(a1[0], a1[1], a1[2], color="#1f77b4", s=70, depthshade=False, label="a1")
ax.scatter(a2[0], a2[1], a2[2], color="#2ca02c", s=70, depthshade=False, label="a2")
ax.scatter(a_g[0], a_g[1], a_g[2], color="#17becf", s=70, depthshade=False, label="$a_g$")
ax.plot_surface(x, y, z, color="#7f8c8d", alpha=0.18, linewidth=0, shade=False)
ax.plot_surface(cap_x, np.full_like(cap_x, h), cap_z, color="#7f8c8d", alpha=0.18, linewidth=0, shade=True)
ax.plot_surface(cap_x, np.full_like(cap_x, -h), cap_z, color="#7f8c8d", alpha=0.18, linewidth=0, shade=True)
ax.quiver(a2[0], a2[1], a2[2], a[0], a[1], a[2], color="#9467bd", linewidth=2.4, arrow_length_ratio=0.12, label="a")
ax.quiver(a2[0], a2[1], a2[2], -p[0] / fact_p, -p[1] / fact_p, -p[2] / fact_p, color="#d62728", linewidth=2.4, arrow_length_ratio=0.12, label="p")
ax.quiver(a1[0], a1[1], a1[2], p[0] / fact_p, p[1] / fact_p, p[2] / fact_p, color="#ff7f0e", linewidth=2.4, arrow_length_ratio=0.12)
ax.quiver(0, 0, 0, omega[0] / fact, omega[1] / fact, omega[2] / fact, color="#120899", linewidth=2.4, arrow_length_ratio=0.52, label="$\\omega$")
draw_rotation_arc(ax, -omega, np.zeros(3), 0.2 * r, "#120899", offset_deg=90.0, arc_length_deg=50.0, arrow_scale=0.8, head_ratio=0.6)
ax.set_xlabel("X [m]")
ax.set_ylabel("Y [m]")
ax.set_zlabel("Z [m]")
ax.set_title(f"min normal/g = {result['min_normal_g']:.3f}")
ax.set_box_aspect((2 * r, d, 2 * r))
ax.view_init(elev=18, azim=35)
ax.grid(False)
plt.show()
