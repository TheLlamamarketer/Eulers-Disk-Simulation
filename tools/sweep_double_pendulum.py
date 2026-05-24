#!/usr/bin/env python3
"""Sweep physically plausible double-pendulum strike settings.

The sweep keeps the launch model intact: theta=0, two opposite face strikes,
and free post-impact center velocity. It varies pendulum strength and impact
geometry, runs the existing headless simulator, and ranks results by lifetime
and low-nutation metrics.
"""

from __future__ import annotations

import argparse
import ast
import csv
import math
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_PRESET = ROOT / "init" / "double_pendulum.responses"
SIM = ROOT / "build_gfortran" / "edisk_headless.exe"
GENERATED = ROOT / "generated"

# Edit this block if you want to run the file directly without command-line
# arguments. Range specs use start:stop:step and include the stop value when it
# lands on the grid. Comma lists and ranges can be mixed.
DEFAULT_END_TIME = 100.0
DEFAULT_PRINT_STEP = 0.001
DEFAULT_TIMEOUT = 12.0
DEFAULT_TOP = 12
DEFAULT_WRITE_BEST = False
DEFAULT_CSV_NAME = "double_pendulum_sweep.csv"
DEFAULT_PLOT_HEATMAP = True
DEFAULT_HEATMAP_NAME = ""

DEFAULT_MASSES = "0.25"
DEFAULT_RELEASES = "27.5"
DEFAULT_DIRECTIONS = "-50:-15:5"
DEFAULT_RADII = "0.045"
DEFAULT_FACE_ANGLES = "0:180:5"

# Positive inward component means a real pendulum can push into the +face.
# Set to 0.0 to include grazing/tangential ideal-impulse hits.
DEFAULT_MIN_INWARD = 0.15

# Safety guard for accidental huge sweeps. Set to 0 to disable.
DEFAULT_MAX_CANDIDATES = 2000


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
    mass: float
    release_deg: float
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
                if (step > 0.0 and value <= stop + 1.0e-9) or (step < 0.0 and value >= stop - 1.0e-9):
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
    if len(values) != 34:
        raise RuntimeError(f"expected 34 preset values in {path}, found {len(values)}")
    return values


def format_response(values: list[float]) -> str:
    return "\n".join(f"{value:.12g}" for value in values) + "\n"


def mirror_angle_deg(angle: float) -> float:
    return (angle + 180.0) % 360.0


def inward_component(direction_deg: float) -> float:
    """Inward impulse component for the first +face strike.

    The first strike is on +face, so a real pendulum must push with negative Y.
    The mirrored second strike gets direction+180 and is physical at the -face
    whenever this first inward component is positive.
    """

    return -math.sin(math.radians(direction_deg))


def incidence_deg(direction_deg: float) -> float:
    value = max(-1.0, min(1.0, inward_component(direction_deg)))
    return math.degrees(math.asin(value))


def response_for(base: list[float], candidate: Candidate, end_time: float, print_step: float) -> str:
    values = list(base)

    values[5] = 0.0     # theta must remain vertical.
    values[7] = 2.0     # double pendulum mode.
    values[8] = candidate.mass
    values[10] = candidate.release_deg
    values[13] = candidate.direction_deg
    values[15] = candidate.face_radius
    values[16] = candidate.face_angle_deg
    values[17] = 0.0 
    values[18] = candidate.mass
    values[20] = candidate.release_deg
    values[23] = candidate.direction_deg + 180.0
    values[24] = mirror_angle_deg(candidate.face_angle_deg)
    values[30] = end_time
    values[31] = print_step

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

    return {
        "end_time": number_after("end time"),
        "exit_status": int_after("exit status code"),
        "cpu_time": number_after("CPU time"),
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


def run_candidate(
    base: list[float],
    candidate: Candidate,
    end_time: float,
    print_step: float,
    timeout: float,
    min_inward: float = 0.0,
) -> dict[str, float | int | str | bool]:
    row: dict[str, float | int | str | bool] = {
        "mass": candidate.mass,
        "release_deg": candidate.release_deg,
        "direction_deg": candidate.direction_deg,
        "direction2_deg": candidate.direction_deg + 180.0,
        "face_radius": candidate.face_radius,
        "face_angle_deg": candidate.face_angle_deg,
        "face2_angle_deg": mirror_angle_deg(candidate.face_angle_deg),
        "inward_component": inward_component(candidate.direction_deg),
        "incidence_deg": incidence_deg(candidate.direction_deg),
        "physical_hit": inward_component(candidate.direction_deg) >= min_inward,
        "skipped_physical": False,
        "timed_out": False,
    }

    if not bool(row["physical_hit"]):
        row.update({
            "wall_time": 0.0,
            "end_time": 0.0,
            "exit_status": -998,
            "score": -1.0e9,
            "skipped_physical": True,
        })
        return row

    response = response_for(base, candidate, end_time, print_step)
    started = time.perf_counter()
    try:
        proc = subprocess.run(
            [str(SIM)],
            input=response,
            text=True,
            cwd=ROOT,
            capture_output=True,
            timeout=timeout,
        )
        timed_out = False
    except subprocess.TimeoutExpired:
        timed_out = True
        proc = None

    row["wall_time"] = time.perf_counter() - started
    row["timed_out"] = timed_out

    if timed_out:
        row.update({"end_time": 0.0, "exit_status": -999, "score": -999.0})
        return row

    row["process_status"] = proc.returncode if proc is not None else -999
    report_path = ROOT / "report.txt"
    result_path = ROOT / "result.txt"
    if report_path.exists():
        row.update(parse_report(report_path))
    if result_path.exists():
        row.update(parse_result(result_path))
    row["score"] = score_row(row)
    return row


def write_candidate(path: Path, base: list[float], row: dict[str, float | int | str | bool], end_time: float, print_step: float) -> None:
    candidate = Candidate(
        mass=float(row["mass"]),
        release_deg=float(row["release_deg"]),
        direction_deg=float(row["direction_deg"]),
        face_radius=float(row["face_radius"]),
        face_angle_deg=float(row.get("face_angle_deg", 90.0)),
    )
    body = response_for(base, candidate, end_time, print_step)
    path.write_text(body, encoding="ascii")


def output_path(name: str) -> Path:
    path = Path(name)
    return path if path.is_absolute() else GENERATED / path


def plot_heatmap(csv_path: Path, heatmap_name: str) -> Path | None:
    if heatmap_name:
        output = output_path(heatmap_name)
    else:
        output = csv_path.with_name(csv_path.stem + "_heatmap.svg")

    plotter = ROOT / "tools" / "plot_phi_sweep_heatmap.py"
    if not plotter.exists():
        print(f"Heatmap skipped: missing plotter {plotter}", file=sys.stderr)
        return None

    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [sys.executable, str(plotter), str(csv_path), "--output", str(output)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--end-time", type=float, default=DEFAULT_END_TIME)
    parser.add_argument("--print-step", type=float, default=DEFAULT_PRINT_STEP)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument("--top", type=int, default=DEFAULT_TOP)
    parser.add_argument("--write-best", action="store_true", default=DEFAULT_WRITE_BEST)
    parser.add_argument("--masses", default=DEFAULT_MASSES)
    parser.add_argument("--releases", default=DEFAULT_RELEASES)
    parser.add_argument("--directions", default=DEFAULT_DIRECTIONS)
    parser.add_argument("--radii", default=DEFAULT_RADII)
    parser.add_argument("--face-angles", default=DEFAULT_FACE_ANGLES)
    parser.add_argument("--csv-name", default=DEFAULT_CSV_NAME)
    parser.add_argument("--heatmap-name", default=DEFAULT_HEATMAP_NAME)
    parser.add_argument("--plot-heatmap", dest="plot_heatmap", action="store_true", default=DEFAULT_PLOT_HEATMAP)
    parser.add_argument("--no-plot-heatmap", dest="plot_heatmap", action="store_false")
    parser.add_argument(
        "--max-candidates",
        type=int,
        default=DEFAULT_MAX_CANDIDATES,
        help="Abort before running if candidate count is larger. Use 0 to disable.",
    )
    parser.add_argument(
        "--min-inward",
        type=float,
        default=DEFAULT_MIN_INWARD,
        help="Minimum inward face-normal component for a physical pendulum hit. Use 0 to allow grazing hits.",
    )
    args = parser.parse_args()

    if not SIM.exists():
        print(f"missing simulator: {SIM}", file=sys.stderr)
        print("Run `cmd /c run.bat init\\double_pendulum.responses` once to build it.", file=sys.stderr)
        return 2

    base = read_base_values(BASE_PRESET)

    masses = parse_float_spec(args.masses)
    releases = parse_float_spec(args.releases)
    directions = parse_float_spec(args.directions)
    radii = parse_float_spec(args.radii)
    face_angles = parse_float_spec(args.face_angles)

    candidates = [
        Candidate(
            mass=m,
            release_deg=release,
            direction_deg=direction,
            face_radius=radius,
            face_angle_deg=face_angle,
        )
        for m in masses
        for release in releases
        for direction in directions
        for radius in radii
        for face_angle in face_angles
    ]
    print(
        "Sweep grid: "
        f"{len(masses)} masses x {len(releases)} releases x "
        f"{len(directions)} directions x {len(radii)} radii x "
        f"{len(face_angles)} face angles = {len(candidates)} candidates"
    )
    print(
        f"directions={directions}\n"
        f"face_angles={face_angles}\n"
        f"min_inward={args.min_inward}  end_time={args.end_time}  print_step={args.print_step}"
    )
    if args.max_candidates > 0 and len(candidates) > args.max_candidates:
        print(
            f"Refusing to run {len(candidates)} candidates because --max-candidates={args.max_candidates}.",
            file=sys.stderr,
        )
        print(
            "Make the grid coarser, increase DEFAULT_MAX_CANDIDATES, or pass --max-candidates 0.",
            file=sys.stderr,
        )
        print("No CSV or heatmap was written because no runs were executed.", file=sys.stderr)
        return 2

    GENERATED.mkdir(exist_ok=True)
    rows: list[dict[str, float | int | str | bool]] = []
    for idx, candidate in enumerate(candidates, 1):
        row = run_candidate(base, candidate, args.end_time, args.print_step, args.timeout, args.min_inward)
        rows.append(row)
        print(
            f"{idx:4d}/{len(candidates)} "
            f"score={float(row.get('score', -999.0)):7.3f} "
            f"end={float(row.get('end_time', 0.0)):7.3f} "
            f"m={candidate.mass:.3g} rel={candidate.release_deg:.1f} "
            f"dir={candidate.direction_deg:.1f} phi={candidate.face_angle_deg:.1f} "
            f"rad={candidate.face_radius:.3f} in={float(row.get('inward_component', math.nan)):.2f} "
            f"wob={float(row.get('initial_wobble_axis', math.nan)):.3f} "
            f"theta_excess={float(row.get('theta_excess_rate', math.nan)):.2e} "
            f"orbit={float(row.get('center_orbit_rms_m', math.nan)):.4f}"
        )

    rows.sort(key=lambda r: float(r.get("score", -999.0)), reverse=True)
    fieldnames = sorted({key for row in rows for key in row.keys()})
    csv_path = output_path(args.csv_name)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {csv_path}")

    if args.plot_heatmap:
        try:
            heatmap_path = plot_heatmap(csv_path, args.heatmap_name)
            if heatmap_path is not None:
                print(f"Wrote {heatmap_path}")
        except subprocess.CalledProcessError as exc:
            if exc.stderr:
                print(exc.stderr.strip(), file=sys.stderr)
            print(f"Heatmap failed after CSV write: {exc}", file=sys.stderr)

    print("\nTop candidates:")
    for rank, row in enumerate(rows[: args.top], 1):
        print(
            f"{rank:2d}. score={float(row.get('score', -999.0)):7.3f} "
            f"end={float(row.get('end_time', 0.0)):7.3f} "
            f"status={row.get('exit_status')} "
            f"m={float(row['mass']):.3g} release={float(row['release_deg']):.1f} "
            f"dir={float(row['direction_deg']):.1f}/{float(row['direction_deg']) + 180.0:.1f} "
            f"phi={float(row.get('face_angle_deg', 90.0)):.1f}/{float(row.get('face2_angle_deg', 270.0)):.1f} "
            f"radius={float(row['face_radius']):.3f} "
            f"in={float(row.get('inward_component', math.nan)):.2f} "
            f"wob={float(row.get('initial_wobble_axis', math.nan)):.3f} "
            f"theta_excess={float(row.get('theta_excess_rate', math.nan)):.2e} "
            f"orbit={float(row.get('center_orbit_rms_m', math.nan)):.4f} "
            f"cpu={float(row.get('cpu_time', math.nan)):.3f}"
        )

    if args.write_best and rows:
        best_path = GENERATED / "best_double_pendulum.responses"
        write_candidate(best_path, base, rows[0], args.end_time, args.print_step)
        best_candidate = Candidate(
            mass=float(rows[0]["mass"]),
            release_deg=float(rows[0]["release_deg"]),
            direction_deg=float(rows[0]["direction_deg"]),
            face_radius=float(rows[0]["face_radius"]),
            face_angle_deg=float(rows[0].get("face_angle_deg", 90.0)),
        )
        best_row = run_candidate(base, best_candidate, args.end_time, args.print_step, args.timeout, args.min_inward)
        shutil.copy2(ROOT / "report.txt", GENERATED / "best_sweep_report.txt")
        shutil.copy2(ROOT / "result.txt", GENERATED / "best_sweep_result.txt")
        print(
            f"\nBest rerun: end={float(best_row.get('end_time', 0.0)):.3f} "
            f"status={best_row.get('exit_status')} "
            f"cpu={float(best_row.get('cpu_time', math.nan)):.3f}"
        )
        print(f"\nWrote {best_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
