#!/usr/bin/env python3
"""Score paired face-impulse geometry without running the full simulator."""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

from launch_model import G, disk_volume, normal_load_scan as scan_normal_load


NORMAL_MARGIN_G = 0.25
LIFTOFF_COST = 1.0e6
AXIS_SPIN_TARGET = 15.0
MIN_INWARD = 0.15
PHYSICAL_IMPACT_COST = 1.0e6


def skew(v):
    return np.array([
        [0, -v[2], v[1]],
        [v[2], 0, -v[0]],
        [-v[1], v[0], 0]
    ])


def normal_load_scan(
    omega,
    r,
    d,
    rho,
    vc=(0.0, 0.0),
    theta0=0.0,
    horizon=0.02,
    samples=401,
    **kwargs,
):
    """Approximate early post-impact contact safety with frozen omega."""

    xk12 = (3.0 * r**2 + d**2) / 12.0
    xk22 = 0.5 * r**2
    scan = scan_normal_load(
        tuple(float(value) for value in omega),
        r,
        d,
        rho,
        xk12,
        xk22,
        tuple(float(value) for value in vc),
        kwargs.get("mu_k", 0.25),
        kwargs.get("rolling_scales", (0.00018, 0.00065, 0.0008))[0],
        theta0=theta0,
        horizon=horizon,
        samples=samples,
    )
    return {
        "min_fz": scan["startup_min_normal"],
        "min_fz_g": scan["startup_min_normal_g"],
        "time": scan["startup_min_normal_time"],
        "theta": scan["startup_min_normal_theta"],
    }


def startup_eval(
    phi1,
    phip,
    r=0.05,
    d=0.01,
    rho=0.001,
    r_frac=0.9,
    p_mag=0.139,
    m=None,
    density=7792.0,
    mu=0.45,
    mu_k=0.25,
):
    if m is None:
        m = density * disk_volume(r, d, rho)

    h = d/2
    
    phi2 = phi1 + np.pi
    r1 = r * r_frac
    r2 = r * r_frac
    
    p = p_mag*np.array([np.cos(phip), -np.sin(phip), 0.0])
    
    a1 = np.array([r1*np.cos(phi1), h, r1*np.sin(phi1)])
    a2 = np.array([r2*np.cos(phi2), -h, r2*np.sin(phi2)])
    a = a1 - a2
    
    L = np.cross(a, p)
    
    Ix = 1/12 *m*(3*r**2 + d**2)
    Iy = 1/2 *m*r**2
    Iz = Ix
    
    I = np.diag([Ix, Iy, Iz])
    I_inv = np.diag([1/Ix, 1/Iy, 1/Iz])
    
    omega = I_inv @ L
    
    spin = abs(omega[1])
    precession = np.sqrt(omega[0]**2 + omega[2]**2)
    
    eps = 1e-12
    nutation = precession/ (spin + eps)
    
    # Bottom contact endpoints of the line
    ag_candidates = [
        np.array([0.0, -h, -r]),
        np.array([0.0, +h, -r]),
    ]

    # Choose the endpoint that tries to penetrate the floor most strongly
    vc_candidates = [np.cross(omega, ag) for ag in ag_candidates]
    vz_values = [vc[2] for vc in vc_candidates]
    idx = int(np.argmin(vz_values))

    ag = ag_candidates[idx]
    vc = vc_candidates[idx]
    
    slip_speed = np.linalg.norm(vc[:2])
    vertical_speed = abs(vc[2])
    normal = normal_load_scan(omega, r, d, rho, mu_k=mu_k)
    
    A = skew(ag)
    K = np.eye(3) / m - A @ I_inv @ A

    try:
        j_stick = np.linalg.solve(K, -vc)
        jn = j_stick[2]
        jt = np.linalg.norm(j_stick[:2])

        if jn <= 0:
            friction_bad = 10.0
            contact_state = 0
        else:
            friction_ratio = jt / (mu * jn + eps)
            friction_bad = max(0.0, friction_ratio - 1.0)
            contact_state = 1 if friction_ratio <= 1.0 else 2

    except np.linalg.LinAlgError:
        friction_bad = 10.0
        contact_state = -1

    normal_bad = max(0.0, NORMAL_MARGIN_G - normal["min_fz_g"])
    if normal["min_fz_g"] <= 0.0:
        contact_state = 0
    safe_contact = normal["min_fz_g"] >= NORMAL_MARGIN_G
    spin_shortfall = max(0.0, AXIS_SPIN_TARGET - spin) / AXIS_SPIN_TARGET
    tip_spin = abs(omega[0]) / (spin + eps)
    inward = np.sin(phip)
    physical_hit = inward >= MIN_INWARD

    # Lower is better. The simulator starts in sliding, so the instantaneous
    # sticking impulse is only a weak diagnostic; the early normal load and
    # wobble/axis ratio matter much more.
    score = (
        (LIFTOFF_COST if normal["min_fz_g"] <= 0.0 else 0.0)
        + (PHYSICAL_IMPACT_COST if not physical_hit else 0.0)
        + 500.0 * normal_bad
        + 80.0 * nutation
        + 120.0 * tip_spin
        + 25.0 * spin_shortfall
        + 0.20 * slip_speed
        + 20.0 * vertical_speed
    )

    return {
        "score": score,
        "spin": spin,
        "nutation_ratio": nutation,
        "slip_speed": slip_speed,
        "vertical_speed": vertical_speed,
        "omega": omega,
        "vc": vc,
        "ag": ag,
        "min_normal_g": normal["min_fz_g"],
        "min_normal_time": normal["time"],
        "min_normal_theta": normal["theta"],
        "normal_margin_g": NORMAL_MARGIN_G,
        "safe_contact": safe_contact,
        "friction_bad": friction_bad,
        "tip_spin_ratio": tip_spin,
        "inward_component": inward,
        "physical_hit": physical_hit,
        "contact_state": contact_state,
    }


def main():
    # phip is positive-clockwise here; phip=70 deg matches a simulator strike
    # direction of -70 deg.
    phi1_deg_values = np.linspace(0.0, 180.0, 361)
    phi_p_deg_values = np.linspace(0.0, 89.0, 241)

    score_grid = np.zeros((len(phi_p_deg_values), len(phi1_deg_values)))
    spin_grid = np.zeros_like(score_grid)
    nutation_grid = np.zeros_like(score_grid)
    slip_grid = np.zeros_like(score_grid)
    vertical_grid = np.zeros_like(score_grid)
    normal_grid = np.zeros_like(score_grid)

    for i, phi_p_deg in enumerate(phi_p_deg_values):
        for j, phi1_deg in enumerate(phi1_deg_values):
            result = startup_eval(np.radians(phi1_deg), np.radians(phi_p_deg))
            score_grid[i, j] = result["score"]
            spin_grid[i, j] = result["spin"]
            nutation_grid[i, j] = result["nutation_ratio"]
            slip_grid[i, j] = result["slip_speed"]
            vertical_grid[i, j] = result["vertical_speed"]
            normal_grid[i, j] = result["min_normal_g"]

    best_idx = np.unravel_index(np.argmin(score_grid), score_grid.shape)
    best_phi1 = phi1_deg_values[best_idx[1]]
    best_phi_p = phi_p_deg_values[best_idx[0]]
    best_score = score_grid[best_idx]

    print(f"Best score: {best_score:.4f} at phi1={best_phi1:.1f} deg, phi_p={best_phi_p:.1f} deg")
    best = startup_eval(np.radians(best_phi1), np.radians(best_phi_p))
    print("Best Omega:", best["omega"])
    print("Best contact velocity:", best["vc"])
    print("Best contact point:", best["ag"])
    print(
        "Min normal/g:",
        best["min_normal_g"],
        "at t:",
        best["min_normal_time"],
        "safe:",
        best["safe_contact"],
    )
    print("Inward component:", best["inward_component"], "physical:", best["physical_hit"])
    print("Contact state:", best["contact_state"], "(2 means sliding, not lift-off)")
    print("Responses direction 1 [deg]:", -best_phi_p)
    print("Responses face angle 1 [deg]:", best_phi1)
    print("Responses direction 2 [deg]:", 180.0 - best_phi_p)
    print("Responses face angle 2 [deg]:", best_phi1 + 180.0)

    plt.figure(figsize=(10, 5))
    score_positive = score_grid[score_grid > 0]
    score_vmin = float(score_positive.min()) if score_positive.size else 1e-6
    score_vmax = float(score_grid.max())
    plt.contourf(
        phi1_deg_values,
        phi_p_deg_values,
        score_grid,
        levels=np.logspace(np.log10(score_vmin), np.log10(score_vmax), 80),
        norm=LogNorm(vmin=score_vmin, vmax=score_vmax),
    )
    plt.colorbar(label="score, lower is better")
    plt.scatter([best_phi1], [best_phi_p], color="white", edgecolor="black", s=80, label="best")
    plt.xlabel(r"$\phi_1$ in degrees")
    plt.ylabel(r"$\phi_p$ in degrees")
    plt.title("Start quality score")
    plt.legend()
    plt.tight_layout()
    plt.show()

    fig, axs = plt.subplots(1, 4, figsize=(18, 4), constrained_layout=True)

    im0 = axs[0].contourf(phi1_deg_values, phi_p_deg_values, nutation_grid, levels=80)
    axs[0].set_title("nutation ratio")
    axs[0].set_xlabel(r"$\phi_1$")
    axs[0].set_ylabel(r"$\phi_p$")
    fig.colorbar(im0, ax=axs[0])

    im1 = axs[1].contourf(phi1_deg_values, phi_p_deg_values, slip_grid, levels=80)
    axs[1].set_title("horizontal slip speed")
    axs[1].set_xlabel(r"$\phi_1$")
    axs[1].set_ylabel(r"$\phi_p$")
    fig.colorbar(im1, ax=axs[1])

    im2 = axs[2].contourf(phi1_deg_values, phi_p_deg_values, vertical_grid, levels=80)
    axs[2].set_title("vertical contact speed")
    axs[2].set_xlabel(r"$\phi_1$")
    axs[2].set_ylabel(r"$\phi_p$")
    fig.colorbar(im2, ax=axs[2])

    im3 = axs[3].contourf(phi1_deg_values, phi_p_deg_values, normal_grid, levels=80)
    axs[3].contour(phi1_deg_values, phi_p_deg_values, normal_grid, levels=[0.0], colors="white")
    axs[3].contour(phi1_deg_values, phi_p_deg_values, normal_grid, levels=[NORMAL_MARGIN_G], colors="black")
    axs[3].set_title("min normal/g")
    axs[3].set_xlabel(r"$\phi_1$")
    axs[3].set_ylabel(r"$\phi_p$")
    fig.colorbar(im3, ax=axs[3])

    plt.show()


if __name__ == "__main__":
    main()

