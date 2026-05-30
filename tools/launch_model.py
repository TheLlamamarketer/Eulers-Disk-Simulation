#!/usr/bin/env python3
"""Shared launch-search helpers for the Euler disk tools."""

from __future__ import annotations

import ast
import math
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_PRESET = ROOT / "init" / "double_pendulum.responses"
SIM = ROOT / "build_gfortran" / "edisk_headless.exe"
GENERATED = ROOT / "generated"

PRESET_VALUE_COUNT = 26
IDX_RADIUS = 0
IDX_HEIGHT = 1
IDX_FILLET = 2
IDX_DENSITY = 3
IDX_PSI_DEG = 4
IDX_THETA_DEG = 5
IDX_LAUNCH_MODE = 7
IDX_RELEASE_ANGLE = 8
IDX_IMPACT_ANGLE = 9
IDX_RESTITUTION = 10
IDX_EFFICIENCY = 11
IDX_DIRECTION = 12
IDX_SURFACE = 13
IDX_FACE_RADIUS = 14
IDX_FACE_ANGLE = 15
IDX_VELOCITY_MODE = 16
IDX_MU_K = 18
IDX_ROLLING_X = 19
IDX_END_TIME = 22
IDX_PRINT_STEP = 23

G = 9.8067
THETA_LINE_SMOOTH = 2.0e-2
SLIP_REGULARIZATION = 1.0e-3
PHYSICAL_PEND_MASS = 0.39522465
PHYSICAL_PEND_COM = 0.3605
PHYSICAL_PEND_CONTACT = 0.7375
PHYSICAL_PEND_INERTIA_CM = 0.017704504
PHYSICAL_PEND_INERTIA_PIVOT = PHYSICAL_PEND_INERTIA_CM + PHYSICAL_PEND_MASS * PHYSICAL_PEND_COM**2


def simulator_stale_reason() -> str:
    if not SIM.exists():
        return f"missing simulator: {SIM}"

    sources = [ROOT / "zeroin.f"]
    for folder in (ROOT / "model2", ROOT / "screen", ROOT / "hairer"):
        for pattern in ("*.f90", "*.f", "*.for"):
            sources.extend(folder.glob(pattern))

    existing_sources = [path for path in sources if path.exists()]
    newest = max(existing_sources, key=lambda path: path.stat().st_mtime)
    if SIM.stat().st_mtime < newest.stat().st_mtime:
        return f"simulator is older than {newest.relative_to(ROOT)}"
    return ""


SAFE_OPS = {
    ast.Add: lambda a, b: a + b,
    ast.Sub: lambda a, b: a - b,
    ast.Mult: lambda a, b: a * b,
    ast.Div: lambda a, b: a / b,
    ast.USub: lambda a: -a,
    ast.UAdd: lambda a: a,
}


@dataclass
class Candidate:
    release_angle_deg: float
    impact_angle_deg: float
    direction_deg: float
    face_radius: float
    face_angle_deg: float = 90.0


def eval_number(text: str) -> float:
    node = ast.parse(text, mode="eval").body

    def walk(n: ast.AST) -> float:
        if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)):
            return float(n.value)
        if isinstance(n, ast.UnaryOp) and type(n.op) in SAFE_OPS:
            return SAFE_OPS[type(n.op)](walk(n.operand))
        if isinstance(n, ast.BinOp) and type(n.op) in SAFE_OPS:
            return SAFE_OPS[type(n.op)](walk(n.left), walk(n.right))
        raise ValueError(f"unsupported numeric expression: {text!r}")

    return walk(node)


def parse_float_spec(text: str) -> list[float]:
    values: list[float] = []
    for raw_item in text.split(","):
        item = raw_item.strip()
        if not item:
            continue
        if ":" in item:
            parts = [part.strip() for part in item.split(":")]
            if len(parts) != 3:
                raise ValueError(f"range spec must be start:stop:step, got {item!r}")
            start, stop, step = (eval_number(part) for part in parts)
            if step == 0.0:
                raise ValueError(f"range step cannot be zero in {item!r}")
            if (stop - start) * step < 0.0:
                step = -step
            count = int(math.floor((stop - start) / step + 1.0e-9)) + 1
            for idx in range(max(0, count)):
                value = start + idx * step
                if (step > 0.0 and value <= stop + 1.0e-9) or (
                    step < 0.0 and value >= stop - 1.0e-9
                ):
                    values.append(round(value, 10))
        else:
            values.append(eval_number(item))
    return values


def read_base_values(path: Path) -> list[float]:
    values: list[float] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            values.append(eval_number(line))
    if len(values) != PRESET_VALUE_COUNT:
        raise RuntimeError(
            f"expected {PRESET_VALUE_COUNT} preset values in {path}, found {len(values)}"
        )
    return values


def format_response(values: list[float]) -> str:
    return "\n".join(f"{value:.12g}" for value in values) + "\n"


def mirror_angle_deg(angle: float) -> float:
    return (angle + 180.0) % 360.0


def inward_component(direction_deg: float) -> float:
    """Inward impulse component for the first +face strike."""

    return -math.sin(math.radians(direction_deg))


def incidence_deg(direction_deg: float) -> float:
    value = max(-1.0, min(1.0, inward_component(direction_deg)))
    return math.degrees(math.asin(value))


def disk_volume(radius: float, height: float, fillet: float) -> float:
    if radius <= 0.0 or height <= 0.0:
        return 0.0
    f = max(0.0, min(fillet, height / 2.0, radius))
    volume = math.pi * (
        height * radius**2
        + math.pi * radius * f**2
        - math.pi * f**3
        + (10.0 / 3.0) * f**3
        - 4.0 * radius * f**2
    )
    return volume if volume > 0.0 else math.pi * radius**2 * height


def prop_radii(radius: float, height: float, fillet: float) -> tuple[float, float]:
    """Return the same x/z and y radii of gyration as model2/prop.f."""

    if height == 0.0:
        xk22 = 0.5 * radius**2
        return 0.5 * xk22, xk22

    pi = math.pi
    r = radius
    h = height
    rho = fillet
    xk22 = (
        105 * pi * rho**5
        - 332 * rho**5
        + 720 * r * rho**4
        - 225 * pi * r * rho**4
        - 600 * r**2 * rho**3
        + 180 * pi * r**2 * rho**3
        - 60 * pi * r**3 * rho**2
        + 240 * r**3 * rho**2
        - 30 * r**4 * h
    ) / (
        -3 * h * r**2
        - 3 * pi * r * rho**2
        + 3 * pi * rho**3
        - 10 * rho**3
        + 12 * r * rho**2
    ) / 20.0
    xk12 = (
        pi * r**4 * h / 4.0
        + pi**2 * r**3 * rho**2 / 2.0
        - 1.5 * pi**2 * r**2 * rho**3
        + 25.0 / 8.0 * pi**2 * r * rho**4
        - 17.0 / 8.0 * pi**2 * rho**5
        - 2.0 * pi * r**3 * rho**2
        + 5.0 * pi * r**2 * rho**3
        - 10.0 * pi * r * rho**4
        + 67.0 / 10.0 * pi * rho**5
        + pi * r**2 * h**3 / 12.0
        + r * pi**2 * h**2 * rho**2 / 4.0
        - r * pi**2 * h * rho**3
        + 10.0 / 3.0 * r * pi * h * rho**3
        - 19.0 / 6.0 * pi * h * rho**4
        + 5.0 / 6.0 * pi * h**2 * rho**3
        + pi**2 * h * rho**4
        - pi**2 * h**2 * rho**3 / 4.0
        - r * pi * h**2 * rho**2
    ) / (
        -pi * (3.0 * pi - 10.0) * rho**3 / 3.0
        + pi * r * (pi - 4.0) * rho**2
        + pi * h * r**2
    )
    return xk12, xk22


def contact_geometry(
    theta: float,
    radius: float,
    height: float,
    fillet: float,
    theta_line_smooth: float = THETA_LINE_SMOOTH,
) -> tuple[float, float, float, float, float]:
    """Match the near-vertical contact geometry used by model2/disk0.f90."""

    hh = height / 2.0
    sith = math.sin(theta)
    coth = math.cos(theta)
    abth = abs(theta)

    if theta_line_smooth > 0.0 and abth < theta_line_smooth:
        u = theta / theta_line_smooth
        sig = 1.5 * u - 0.5 * u**3
        dsig = (1.5 - 1.5 * u**2) / theta_line_smooth
        hmag = hh - fillet * (1.0 - abs(sith))
        if theta > 0.0:
            dhmag = fillet * coth
        elif theta < 0.0:
            dhmag = -fillet * coth
        else:
            dhmag = 0.0
        hp = hmag * sig
        dhp = dhmag * sig + hmag * dsig
        rp = radius - fillet * (1.0 - coth)
        drp = -fillet * sith
    elif theta == 0.0:
        hp = 0.0
        rp = radius
        dhp = fillet
        drp = 0.0
    elif 0.0 < theta <= math.pi / 2.0:
        hp = hh - fillet * (1.0 - sith)
        rp = radius - fillet * (1.0 - coth)
        dhp = fillet * coth
        drp = -fillet * sith
    elif -math.pi / 2.0 <= theta < 0.0:
        hp = -hh + fillet * (1.0 + sith)
        rp = radius - fillet * (1.0 - coth)
        dhp = fillet * coth
        drp = -fillet * sith
    else:
        hp = math.copysign(hh, theta)
        rp = 0.0
        dhp = math.copysign(1.0, theta)
        drp = 0.0

    yp = -hp * coth + rp * sith
    zp = -(hp * sith + rp * coth)
    dyp = -dhp * coth + drp * sith - zp
    return hp, rp, yp, zp, dyp


def sliding_normal_load(
    omega: tuple[float, float, float],
    theta: float,
    radius: float,
    height: float,
    fillet: float,
    xk12: float,
    xk22: float,
    vc: tuple[float, float],
    mu_k: float,
    rolling_x_over_radius: float,
) -> float:
    omega1, omega2, omega3 = omega
    hp, rp, yp, zp, dyp = contact_geometry(theta, radius, height, fillet)
    sith = math.sin(theta)
    coth = math.cos(theta)
    tanth = sith / coth

    xmurx = rolling_x_over_radius * radius
    xm1 = 0.0 if omega1 == 0.0 else -xmurx * math.copysign(1.0, omega1)

    vcx, vcy = vc
    vpx = vcx - rp * omega2 + hp * omega3
    vpy = vcy - zp * omega1
    vp_eff = math.hypot(math.hypot(vpx, vpy), SLIP_REGULARIZATION)
    xmuy = -mu_k * vpy / vp_eff

    a = xk22 * omega2 - xk12 * tanth * omega3
    b3 = G - omega1**2 * dyp
    denom = xk12 + yp * (yp + xm1 - xmuy * zp)
    return (xk12 * b3 - yp * omega3 * a) / denom


def normal_load_scan(
    omega: tuple[float, float, float],
    radius: float,
    height: float,
    fillet: float,
    xk12: float,
    xk22: float,
    vc: tuple[float, float],
    mu_k: float,
    rolling_x_over_radius: float,
    theta0: float = 0.0,
    horizon: float = 0.02,
    samples: int = 401,
) -> dict[str, float]:
    min_fz = math.inf
    min_time = 0.0
    min_theta = theta0
    denom = max(1, samples - 1)
    for idx in range(samples):
        time_value = horizon * idx / denom
        theta = theta0 + omega[0] * time_value
        fz = sliding_normal_load(
            omega,
            theta,
            radius,
            height,
            fillet,
            xk12,
            xk22,
            vc,
            mu_k,
            rolling_x_over_radius,
        )
        if fz < min_fz:
            min_fz = fz
            min_time = time_value
            min_theta = theta
    return {
        "startup_min_normal": min_fz,
        "startup_min_normal_g": min_fz / G,
        "startup_min_normal_time": min_time,
        "startup_min_normal_theta": min_theta,
    }


def face_point(
    surface: int,
    radius: float,
    height: float,
    angle_deg: float,
) -> tuple[float, float, float]:
    angle = math.radians(angle_deg)
    y = height / 2.0 if surface == 1 else -height / 2.0
    return radius * math.cos(angle), y, radius * math.sin(angle)


def strike_impulse_components(
    release_angle_deg: float,
    impact_angle_deg: float,
    restitution: float,
    efficiency: float,
    direction_deg: float,
    point: tuple[float, float, float],
    disk_mass: float,
    xk12: float,
    xk22: float,
    psi_deg: float,
    theta_deg: float,
) -> dict[str, float]:
    release = math.radians(release_angle_deg)
    impact = math.radians(impact_angle_deg)
    direction = math.radians(direction_deg)
    psi = math.radians(psi_deg)
    theta = math.radians(theta_deg)

    nxw = math.cos(direction)
    nyw = math.sin(direction)
    cpsi = math.cos(psi)
    spsi = math.sin(psi)
    cth = math.cos(theta)
    sth = math.sin(theta)

    nx1 = cpsi * nxw + spsi * nyw
    ny1 = -spsi * nxw + cpsi * nyw
    nx2 = nx1
    ny2 = cth * ny1
    nz2 = -sth * ny1

    px, py, pz = point
    tx = py * nz2 - pz * ny2
    ty = pz * nx2 - px * nz2
    tz = px * ny2 - py * nx2

    ax = tx / (disk_mass * xk12)
    ay = ty / (disk_mass * xk22)
    az = tz / (disk_mass * xk12)
    bx = ay * pz - az * py
    by = az * px - ax * pz
    bz = ax * py - ay * px

    lever = PHYSICAL_PEND_CONTACT * math.cos(impact - direction)
    if abs(lever) <= 1.0e-9:
        raise ValueError("pendulum lever arm is zero")
    pend_effective_mass = PHYSICAL_PEND_INERTIA_PIVOT / (lever * lever)

    denom = 1.0 / pend_effective_mass + 1.0 / disk_mass + nx2 * bx + ny2 * by + nz2 * bz
    if denom <= 0.0:
        raise ValueError("invalid effective mass")

    angle_drop = math.cos(impact) - math.cos(release)
    if angle_drop < 0.0:
        raise ValueError("release angle cannot reach impact angle")
    omega = math.sqrt(
        max(
            0.0,
            2.0 * PHYSICAL_PEND_MASS * G * PHYSICAL_PEND_COM * angle_drop
            / PHYSICAL_PEND_INERTIA_PIVOT,
        )
    )
    speed = abs(omega * lever)
    impulse = efficiency * (1.0 + restitution) * speed / denom
    return {
        "impulse": impulse,
        "speed": speed,
        "pend_effective_mass": pend_effective_mass,
        "domega1": impulse * tx / (disk_mass * xk12),
        "domega2": impulse * ty / (disk_mass * xk22),
        "domega3": impulse * tz / (disk_mass * xk12),
        "dvx": cpsi * impulse * nxw / disk_mass + spsi * impulse * nyw / disk_mass,
        "dvy": -spsi * impulse * nxw / disk_mass + cpsi * impulse * nyw / disk_mass,
    }


def startup_preflight(base: list[float], candidate: Candidate) -> dict[str, float | str | bool]:
    radius = base[IDX_RADIUS]
    height = base[IDX_HEIGHT]
    fillet = base[IDX_FILLET]
    density = base[IDX_DENSITY]
    psi_deg = base[IDX_PSI_DEG]
    theta_deg = 0.0
    disk_mass = density * disk_volume(radius, height, fillet)
    xk12, xk22 = prop_radii(radius, height, fillet)
    surface = int(base[IDX_SURFACE])
    if surface not in (1, 2):
        return {"startup_contact_safe": True, "startup_skip_available": False}

    surface2 = 2 if surface == 1 else 1
    point1 = face_point(surface, candidate.face_radius, height, candidate.face_angle_deg)
    point2 = face_point(surface2, candidate.face_radius, height, mirror_angle_deg(candidate.face_angle_deg))
    try:
        strike1 = strike_impulse_components(
            candidate.release_angle_deg,
            candidate.impact_angle_deg,
            base[IDX_RESTITUTION],
            base[IDX_EFFICIENCY],
            candidate.direction_deg,
            point1,
            disk_mass,
            xk12,
            xk22,
            psi_deg,
            theta_deg,
        )
        strike2 = strike_impulse_components(
            candidate.release_angle_deg,
            candidate.impact_angle_deg,
            base[IDX_RESTITUTION],
            base[IDX_EFFICIENCY],
            candidate.direction_deg + 180.0,
            point2,
            disk_mass,
            xk12,
            xk22,
            psi_deg,
            theta_deg,
        )
    except ValueError as exc:
        return {
            "startup_contact_safe": False,
            "startup_skip_available": True,
            "startup_error": str(exc),
        }

    omega = (
        strike1["domega1"] + strike2["domega1"],
        strike1["domega2"] + strike2["domega2"],
        strike1["domega3"] + strike2["domega3"],
    )
    vc = (strike1["dvx"] + strike2["dvx"], strike1["dvy"] + strike2["dvy"])
    hp, rp, _, zp, _ = contact_geometry(0.0, radius, height, fillet)
    initial_vpx = vc[0] - rp * omega[1] + hp * omega[2]
    initial_vpy = vc[1] - zp * omega[0]
    normal = normal_load_scan(
        omega,
        radius,
        height,
        fillet,
        xk12,
        xk22,
        vc,
        base[IDX_MU_K],
        base[IDX_ROLLING_X],
    )
    wobble = math.hypot(omega[0], omega[2]) / (abs(omega[1]) + 1.0e-30)
    return {
        **normal,
        "startup_contact_safe": normal["startup_min_normal_g"] > 0.0,
        "startup_skip_available": True,
        "startup_wobble_axis": wobble,
        "startup_slip": math.hypot(initial_vpx, initial_vpy),
        "startup_omega1": omega[0],
        "startup_omega2": omega[1],
        "startup_omega3": omega[2],
        "pend_effective_mass": strike1["pend_effective_mass"],
        "pend2_effective_mass": strike2["pend_effective_mass"],
        "initial_wobble_axis": wobble,
        "initial_slip": math.hypot(initial_vpx, initial_vpy),
        "omega1": omega[0],
        "omega2": omega[1],
        "omega3": omega[2],
    }


def response_for(base: list[float], candidate: Candidate, end_time: float, print_step: float) -> str:
    values = list(base)

    values[IDX_THETA_DEG] = 0.0
    values[IDX_LAUNCH_MODE] = 2.0
    values[IDX_RELEASE_ANGLE] = candidate.release_angle_deg
    values[IDX_IMPACT_ANGLE] = candidate.impact_angle_deg
    values[IDX_DIRECTION] = candidate.direction_deg
    values[IDX_FACE_RADIUS] = candidate.face_radius
    values[IDX_FACE_ANGLE] = candidate.face_angle_deg
    values[IDX_VELOCITY_MODE] = 0.0
    values[IDX_END_TIME] = end_time
    values[IDX_PRINT_STEP] = print_step

    return format_response(values)


def parse_report(path: Path) -> dict[str, float | int | str | bool]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lower_text = text.lower()

    def number_after(label: str, default: float = math.nan) -> float:
        match = re.search(re.escape(label) + r"\s+([-+0-9.Ee]+)", text)
        return float(match.group(1)) if match else default

    def int_after(label: str, default: int = -999) -> int:
        match = re.search(re.escape(label) + r"\s+([-+0-9]+)", text)
        return int(match.group(1)) if match else default

    def number_after_pattern(pattern: str, default: float = math.nan) -> float:
        match = re.search(pattern + r"\s+([-+0-9.Ee]+)", text)
        return float(match.group(1)) if match else default

    return {
        "end_time": number_after("end time"),
        "exit_status": int_after("exit status code"),
        "cpu_time": number_after("CPU time"),
        "reported_release_angle_deg": math.degrees(
            number_after_pattern(r"Rod release theta\s+\[rad\]")
        ),
        "reported_impact_angle_deg": math.degrees(
            number_after_pattern(r"Rod impact theta\s+\[rad\]")
        ),
        "reported_impact_speed": number_after_pattern(r"Rod impact speed\s+\[m/s\]"),
        "reported_impulse": number_after_pattern(r"Impact impulse\s+\[Ns\]"),
        "initial_wobble_axis": number_after("Initial omega wobble/axis [-]"),
        "initial_slip": number_after("Initial contact slip    [m/s]"),
        "omega1": number_after("Initial OmegaX          [r/s]"),
        "omega2": number_after("Initial OmegaY          [r/s]"),
        "omega3": number_after("Initial OmegaZ          [r/s]"),
        "mode_changes": len(re.findall(r"change mode at", text)),
        "lost_contact": "lost contact" in lower_text,
        "energy_stop": "energy stop" in lower_text,
        "flat_stop": "stop at" in lower_text or "line contact" in lower_text,
        "step_too_small": "step size too small" in lower_text,
    }


def parse_result(path: Path, motion_ignore_time: float = 3.0) -> dict[str, float | str]:
    time_values: list[float] = []
    theta_values: list[float] = []
    vs_values: list[float] = []
    xmu_values: list[float] = []
    center_x_values: list[float] = []
    center_y_values: list[float] = []
    last_mode = ""

    with path.open("r", encoding="utf-8", errors="replace") as fp:
        next(fp, None)
        for line in fp:
            parts = line.split()
            if len(parts) < 31:
                continue
            try:
                time_values.append(float(parts[0]))
                theta_values.append(float(parts[2]))
                center_x_values.append(float(parts[10]))
                center_y_values.append(float(parts[11]))
                xmu_values.append(float(parts[27]))
                vs_values.append(float(parts[28]))
                last_mode = parts[30]
            except ValueError:
                continue

    if not theta_values:
        return {
            "theta_rms": math.nan,
            "theta_max_abs": math.nan,
            "theta_span": math.nan,
            "theta_excess_variation": math.nan,
            "theta_excess_rate": math.nan,
            "mean_vs": math.nan,
            "max_xmu": math.nan,
            "center_orbit_rms_m": math.nan,
            "center_drift_m": math.nan,
            "center_path_length_m": math.nan,
            "last_mode": last_mode,
        }

    theta_mean_sq = sum(t * t for t in theta_values) / len(theta_values)
    theta_path = sum(
        abs(theta_values[idx] - theta_values[idx - 1])
        for idx in range(1, len(theta_values))
    )
    theta_net = abs(theta_values[-1] - theta_values[0])
    theta_excess = max(0.0, theta_path - theta_net)
    duration = max(1.0e-12, len(theta_values) - 1)

    motion_indices = [
        idx for idx, value in enumerate(time_values)
        if value >= motion_ignore_time
    ]
    if not motion_indices:
        motion_indices = list(range(len(center_x_values)))
    motion_x = [center_x_values[idx] for idx in motion_indices]
    motion_y = [center_y_values[idx] for idx in motion_indices]

    mean_x = sum(motion_x) / len(motion_x)
    mean_y = sum(motion_y) / len(motion_y)
    center_radii = [
        math.hypot(x - mean_x, y - mean_y)
        for x, y in zip(motion_x, motion_y)
    ]
    center_path = sum(
        math.hypot(
            motion_x[idx] - motion_x[idx - 1],
            motion_y[idx] - motion_y[idx - 1],
        )
        for idx in range(1, len(motion_x))
    )
    return {
        "theta_rms": math.sqrt(theta_mean_sq),
        "theta_max_abs": max(abs(t) for t in theta_values),
        "theta_span": max(theta_values) - min(theta_values),
        "theta_excess_variation": theta_excess,
        "theta_excess_rate": theta_excess / duration,
        "mean_vs": sum(vs_values) / len(vs_values) if vs_values else math.nan,
        "max_xmu": max(xmu_values) if xmu_values else math.nan,
        "center_orbit_rms_m": math.sqrt(sum(r * r for r in center_radii) / len(center_radii)),
        "center_drift_m": math.hypot(motion_x[-1] - motion_x[0], motion_y[-1] - motion_y[0]),
        "center_path_length_m": center_path,
        "last_mode": last_mode,
    }


def score_row(row: dict[str, float | int | str | bool]) -> float:
    def as_float(name: str, default: float = 0.0) -> float:
        value = row.get(name, default)
        if value is None or value == "":
            return default
        try:
            number = float(value)
        except (TypeError, ValueError):
            return default
        return number if math.isfinite(number) else default

    def as_bool(name: str) -> bool:
        value = row.get(name, False)
        if isinstance(value, bool):
            return value
        return str(value).strip().lower() in {"1", "true", "yes", "y"}

    end_time = as_float("end_time")
    wobble = as_float("initial_wobble_axis", 99.0)
    mean_vs = as_float("mean_vs", 99.0)
    theta_excess_rate = as_float("theta_excess_rate")
    center_orbit = as_float("center_orbit_rms_m")
    center_drift = as_float("center_drift_m")
    center_path = as_float("center_path_length_m")
    mode_changes = as_float("mode_changes")
    penalty = (
        14.0 * wobble
        + 6000.0 * theta_excess_rate
        + 900.0 * center_orbit
        + 250.0 * center_drift
        + 0.08 * center_path
        + 8.0 * mean_vs
        + 0.02 * mode_changes
    )
    if as_bool("lost_contact"):
        penalty += 1.0e6
    if as_bool("step_too_small"):
        penalty += 2.5e5
    if as_bool("timed_out"):
        penalty += 2.5e5
    exit_status = int(as_float("exit_status", -999.0))
    if exit_status not in (0, 1):
        penalty += 2.5e5
    if as_bool("flat_stop"):
        penalty += 20.0
    return end_time - penalty


def write_candidate(
    path: Path,
    base: list[float],
    row: dict[str, float | int | str | bool],
    end_time: float,
    print_step: float,
) -> None:
    candidate = Candidate(
        release_angle_deg=float(row["release_angle_deg"]),
        impact_angle_deg=float(row["impact_angle_deg"]),
        direction_deg=float(row["direction_deg"]),
        face_radius=float(row["face_radius"]),
        face_angle_deg=float(row.get("face_angle_deg", 90.0)),
    )
    path.write_text(response_for(base, candidate, end_time, print_step), encoding="ascii")
