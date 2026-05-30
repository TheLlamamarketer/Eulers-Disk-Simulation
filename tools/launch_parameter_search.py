#!/usr/bin/env python3
"""Search physical-pendulum launch parameters with the headless simulator."""

from __future__ import annotations

import argparse
import csv
import math
import shutil
import subprocess
import sys
import time
from pathlib import Path

from launch_model import (
    BASE_PRESET,
    GENERATED,
    IDX_DIRECTION,
    IDX_FACE_ANGLE,
    IDX_FACE_RADIUS,
    ROOT,
    SIM,
    Candidate,
    incidence_deg,
    inward_component,
    mirror_angle_deg,
    parse_float_spec,
    parse_report,
    parse_result,
    read_base_values,
    response_for,
    score_row,
    simulator_stale_reason,
    startup_preflight,
    write_candidate,
)


DEFAULT_END_TIME = 100.0
DEFAULT_PRINT_STEP = 0.001
DEFAULT_TIMEOUT = 12.0
DEFAULT_TOP = 12
DEFAULT_WRITE_BEST = False
DEFAULT_CSV_NAME = "launch_parameter_search.csv"
DEFAULT_PLOT_HEATMAP = True
DEFAULT_HEATMAP_NAME = ""

DEFAULT_RELEASE_ANGLES = "-50.73"
DEFAULT_IMPACT_ANGLES = "45"
DEFAULT_DIRECTIONS = ""
DEFAULT_RADII = ""
DEFAULT_FACE_ANGLES = ""

DEFAULT_SKIP_STARTUP_CONTACT = True
# The preflight freezes omega over a short horizon, so keep a small negative
# tolerance instead of treating every grazing prediction as impossible.
DEFAULT_MIN_STARTUP_NORMAL_G = -0.2

# Positive inward component means a real pendulum can push into the +face.
# Set to 0.0 to include grazing/tangential ideal-impulse hits.
DEFAULT_MIN_INWARD = 0.15

# Safety guard for accidental huge searches. Set to 0 to disable.
DEFAULT_MAX_CANDIDATES = 2000


def run_candidate(
    base: list[float],
    candidate: Candidate,
    end_time: float,
    print_step: float,
    timeout: float,
    min_inward: float = 0.0,
    skip_startup_contact: bool = DEFAULT_SKIP_STARTUP_CONTACT,
    min_startup_normal_g: float = DEFAULT_MIN_STARTUP_NORMAL_G,
) -> dict[str, float | int | str | bool]:
    row: dict[str, float | int | str | bool] = {
        "release_angle_deg": candidate.release_angle_deg,
        "impact_angle_deg": candidate.impact_angle_deg,
        "direction_deg": candidate.direction_deg,
        "direction2_deg": candidate.direction_deg + 180.0,
        "face_radius": candidate.face_radius,
        "face_angle_deg": candidate.face_angle_deg,
        "face2_angle_deg": mirror_angle_deg(candidate.face_angle_deg),
        "inward_component": inward_component(candidate.direction_deg),
        "incidence_deg": incidence_deg(candidate.direction_deg),
        "physical_hit": inward_component(candidate.direction_deg) >= min_inward,
        "skipped_physical": False,
        "skipped_contact": False,
        "skip_reason": "",
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

    row.update(startup_preflight(base, candidate))
    if skip_startup_contact and row.get("startup_error"):
        row.update({
            "wall_time": 0.0,
            "end_time": 0.0,
            "exit_status": -996,
            "score": -1.0e9,
            "lost_contact": True,
            "skipped_contact": True,
            "skip_reason": str(row["startup_error"]),
            "last_mode": "preflight",
        })
        return row

    try:
        startup_min_normal_g = float(row.get("startup_min_normal_g", math.inf))
    except (TypeError, ValueError):
        startup_min_normal_g = math.inf
    if skip_startup_contact and startup_min_normal_g <= min_startup_normal_g:
        row.update({
            "wall_time": 0.0,
            "end_time": 0.0,
            "exit_status": -997,
            "score": -1.0e9,
            "lost_contact": True,
            "skipped_contact": True,
            "skip_reason": "startup normal force <= threshold",
            "last_mode": "preflight",
        })
        return row

    response_text = response_for(base, candidate, end_time, print_step)
    GENERATED.mkdir(exist_ok=True)
    (GENERATED / "last_launch_candidate.responses").write_text(response_text, encoding="ascii")

    report_path = ROOT / "report.txt"
    result_path = ROOT / "result.txt"
    for output in (report_path, result_path):
        try:
            output.unlink()
        except FileNotFoundError:
            pass

    started = time.perf_counter()
    try:
        proc = subprocess.run(
            [str(SIM)],
            input=response_text,
            text=True,
            cwd=ROOT,
            capture_output=True,
            timeout=timeout,
        )
        timed_out = False
    except subprocess.TimeoutExpired:
        proc = None
        timed_out = True

    row["wall_time"] = time.perf_counter() - started
    row["timed_out"] = timed_out

    if timed_out:
        row.update({"end_time": 0.0, "exit_status": -999, "score": -999.0})
        return row

    row["process_status"] = proc.returncode if proc is not None else -999
    if not report_path.exists():
        row.update({
            "end_time": 0.0,
            "exit_status": proc.returncode if proc is not None else -995,
            "score": -1.0e9,
            "output_missing": True,
            "skip_reason": "simulator did not write report.txt",
            "sim_stdout": (proc.stdout or "").strip()[-300:] if proc is not None else "",
            "sim_stderr": (proc.stderr or "").strip()[-300:] if proc is not None else "",
        })
        return row

    if report_path.exists():
        row.update(parse_report(report_path))
    if result_path.exists():
        row.update(parse_result(result_path))
    else:
        row["result_missing"] = True
    row["score"] = score_row(row)
    return row


def output_path(name: str) -> Path:
    path = Path(name)
    return path if path.is_absolute() else GENERATED / path


def plot_heatmap(csv_path: Path, heatmap_name: str) -> Path | None:
    output = output_path(heatmap_name) if heatmap_name else csv_path.with_name(csv_path.stem + "_heatmap.svg")
    plotter = ROOT / "tools" / "launch_search_heatmap.py"
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


def values_from_spec_or_preset(spec: str, preset_value: float) -> list[float]:
    return parse_float_spec(spec) if spec.strip() else [float(preset_value)]


def build_candidates(args: argparse.Namespace, base: list[float]) -> list[Candidate]:
    release_angles = parse_float_spec(args.release_angles)
    impact_angles = parse_float_spec(args.impact_angles)
    directions = values_from_spec_or_preset(args.directions, base[IDX_DIRECTION])
    radii = values_from_spec_or_preset(args.radii, base[IDX_FACE_RADIUS])
    face_angles = values_from_spec_or_preset(args.face_angles, base[IDX_FACE_ANGLE])

    print(
        "Search grid: "
        f"{len(release_angles)} release angles x {len(impact_angles)} impact angles x "
        f"{len(directions)} directions x {len(radii)} radii x "
        f"{len(face_angles)} face angles"
    )
    print(
        f"directions={directions} {'(from preset)' if not args.directions.strip() else ''}\n"
        f"face_angles={face_angles} {'(from preset)' if not args.face_angles.strip() else ''}\n"
        f"radii={radii} {'(from preset)' if not args.radii.strip() else ''}\n"
        f"min_inward={args.min_inward}  end_time={args.end_time}  print_step={args.print_step}\n"
        f"skip_startup_contact={args.skip_startup_contact}  min_startup_normal_g={args.min_startup_normal_g}"
    )

    return [
        Candidate(
            release_angle_deg=release_angle,
            impact_angle_deg=impact_angle,
            direction_deg=direction,
            face_radius=radius,
            face_angle_deg=face_angle,
        )
        for release_angle in release_angles
        for impact_angle in impact_angles
        for direction in directions
        for radius in radii
        for face_angle in face_angles
    ]


def write_csv(path: Path, rows: list[dict[str, float | int | str | bool]]) -> None:
    fieldnames = sorted({key for row in rows for key in row.keys()})
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Search physical-pendulum launch parameters. Each candidate runs the "
            "headless simulator, then writes end_time, score, and diagnostics to CSV. "
            "Direction, radius, and face angle stay at the preset unless you pass "
            "their options."
        )
    )
    parser.add_argument("--end-time", type=float, default=DEFAULT_END_TIME, help="Maximum simulated time for each candidate.")
    parser.add_argument("--print-step", type=float, default=DEFAULT_PRINT_STEP, help="Output sampling step passed to the simulator.")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help="Wall-clock seconds before one candidate is killed.")
    parser.add_argument("--top", type=int, default=DEFAULT_TOP, help="Number of best rows to print.")
    parser.add_argument("--write-best", action="store_true", default=DEFAULT_WRITE_BEST, help="Write the best candidate back to a response file.")
    parser.add_argument("--release-angles", default=DEFAULT_RELEASE_ANGLES, help="Rod release theta grid in degrees, as a list or start:end:step.")
    parser.add_argument("--impact-angles", default=DEFAULT_IMPACT_ANGLES, help="Rod impact theta grid in degrees, as a list or start:end:step.")
    parser.add_argument("--directions", default=DEFAULT_DIRECTIONS, help="Optional pendulum 1 strike-direction grid in degrees. Omit to keep the preset value.")
    parser.add_argument("--radii", default=DEFAULT_RADII, help="Optional face strike-radius grid in model units. Omit to keep the preset value.")
    parser.add_argument("--face-angles", default=DEFAULT_FACE_ANGLES, help="Optional disk-plane face-angle grid in degrees. Omit to keep the preset value.")
    parser.add_argument("--csv-name", default=DEFAULT_CSV_NAME, help="Output CSV name under generated/, unless absolute.")
    parser.add_argument("--heatmap-name", default=DEFAULT_HEATMAP_NAME, help="Optional heatmap SVG name under generated/, unless absolute.")
    parser.add_argument("--plot-heatmap", dest="plot_heatmap", action="store_true", default=DEFAULT_PLOT_HEATMAP)
    parser.add_argument("--no-plot-heatmap", dest="plot_heatmap", action="store_false")
    parser.add_argument("--skip-startup-contact", dest="skip_startup_contact", action="store_true", default=DEFAULT_SKIP_STARTUP_CONTACT)
    parser.add_argument("--no-skip-startup-contact", dest="skip_startup_contact", action="store_false")
    parser.add_argument(
        "--min-startup-normal-g",
        type=float,
        default=DEFAULT_MIN_STARTUP_NORMAL_G,
        help="Skip candidates whose preflight minimum normal force/g is at or below this value.",
    )
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

    stale_reason = simulator_stale_reason()
    if stale_reason:
        print(stale_reason, file=sys.stderr)
        print("Run `cmd /c run.bat --build-only` to rebuild it.", file=sys.stderr)
        return 2

    base = read_base_values(BASE_PRESET)
    candidates = build_candidates(args, base)
    print(f"Candidate count: {len(candidates)}")

    if args.max_candidates > 0 and len(candidates) > args.max_candidates:
        print(
            f"Refusing to run {len(candidates)} candidates because --max-candidates={args.max_candidates}.",
            file=sys.stderr,
        )
        print("Make the grid coarser or pass --max-candidates 0.", file=sys.stderr)
        print("No CSV or heatmap was written because no runs were executed.", file=sys.stderr)
        return 2

    GENERATED.mkdir(exist_ok=True)
    rows: list[dict[str, float | int | str | bool]] = []
    for idx, candidate in enumerate(candidates, 1):
        row = run_candidate(
            base,
            candidate,
            args.end_time,
            args.print_step,
            args.timeout,
            args.min_inward,
            args.skip_startup_contact,
            args.min_startup_normal_g,
        )
        rows.append(row)
        print(
            f"{idx:4d}/{len(candidates)} "
            f"score={float(row.get('score', -999.0)):7.3f} "
            f"end={float(row.get('end_time', 0.0)):7.3f} "
            f"rel={candidate.release_angle_deg:.1f} imp={candidate.impact_angle_deg:.1f} "
            f"dir={candidate.direction_deg:.1f} phi={candidate.face_angle_deg:.1f} "
            f"rad={candidate.face_radius:.3f} in={float(row.get('inward_component', math.nan)):.2f} "
            f"wob={float(row.get('initial_wobble_axis', math.nan)):.3f} "
            f"n0={float(row.get('startup_min_normal_g', math.nan)):.2f} "
            f"theta_excess={float(row.get('theta_excess_rate', math.nan)):.2e} "
            f"orbit={float(row.get('center_orbit_rms_m', math.nan)):.4f}"
        )

    rows.sort(key=lambda row: float(row.get("score", -999.0)), reverse=True)
    csv_path = output_path(args.csv_name)
    write_csv(csv_path, rows)
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
            f"release={float(row['release_angle_deg']):.1f} "
            f"impact={float(row['impact_angle_deg']):.1f} "
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
        best_path = GENERATED / "best_double_pendulum_launch.responses"
        write_candidate(best_path, base, rows[0], args.end_time, args.print_step)
        best_candidate = Candidate(
            release_angle_deg=float(rows[0]["release_angle_deg"]),
            impact_angle_deg=float(rows[0]["impact_angle_deg"]),
            direction_deg=float(rows[0]["direction_deg"]),
            face_radius=float(rows[0]["face_radius"]),
            face_angle_deg=float(rows[0].get("face_angle_deg", 90.0)),
        )
        best_row = run_candidate(
            base,
            best_candidate,
            args.end_time,
            args.print_step,
            args.timeout,
            args.min_inward,
            args.skip_startup_contact,
            args.min_startup_normal_g,
        )
        shutil.copy2(ROOT / "report.txt", GENERATED / "best_launch_search_report.txt")
        shutil.copy2(ROOT / "result.txt", GENERATED / "best_launch_search_result.txt")
        print(
            f"\nBest rerun: end={float(best_row.get('end_time', 0.0)):.3f} "
            f"status={best_row.get('exit_status')} "
            f"cpu={float(best_row.get('cpu_time', math.nan)):.3f}"
        )
        print(f"\nWrote {best_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
