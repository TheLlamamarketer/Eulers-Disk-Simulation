#!/usr/bin/env python3
"""Scan strike direction for one fixed launch setup and plot the timeline.

The map is meant for near-realistic strike-angle questions: keep release theta,
impact theta, radius, and face angle fixed; scan the pendulum 1 direction angle;
set pendulum 2 to angle+180; and draw how long each run stays alive and which
contact mode it is in over time.
"""

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
import time
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

from launch_model import (
    BASE_PRESET,
    GENERATED,
    IDX_END_TIME,
    IDX_FACE_RADIUS,
    IDX_IMPACT_ANGLE,
    IDX_PRINT_STEP,
    IDX_RELEASE_ANGLE,
    SIM,
    Candidate,
    parse_report,
    parse_result,
    read_base_values,
    response_for,
    score_row,
    simulator_stale_reason,
)


MODE_COLORS = {
    "sliding": "#4c78a8",
    "rolling": "#59a14f",
    "stopped": "#e0e0e0",
    "timed-out": "#e15759",
    "unknown": "#b07aa1",
}


def parse_float_list(text: str) -> list[float]:
    return [float(item) for item in text.split(",") if item.strip()]


def build_angles(args: argparse.Namespace) -> list[float]:
    if args.angles:
        values = parse_float_list(args.angles)
    else:
        count = int(round((args.angle_max - args.angle_min) / args.angle_step))
        values = [args.angle_min + i * args.angle_step for i in range(count + 1)]
        if args.include_negative:
            neg = [-value for value in values if abs(value) > 1.0e-12]
            values = sorted(neg + values)
    return sorted(dict.fromkeys(round(value, 8) for value in values))


def parse_timeseries(path: Path) -> list[dict[str, float | str]]:
    samples: list[dict[str, float | str]] = []
    with path.open("r", encoding="utf-8", errors="replace") as fp:
        next(fp, None)
        for line in fp:
            parts = line.split()
            if len(parts) < 31:
                continue
            try:
                samples.append(
                    {
                        "time": float(parts[0]),
                        "theta": float(parts[2]),
                        "center_x": float(parts[10]),
                        "center_y": float(parts[11]),
                        "slip": float(parts[28]),
                        "mode": parts[30].lower(),
                    }
                )
            except ValueError:
                continue
    return samples


def run_angle(
    base: list[float],
    candidate: Candidate,
    end_time: float,
    print_step: float,
    timeout: float,
    motion_ignore_time: float,
) -> tuple[dict[str, float | int | str | bool], list[dict[str, float | str]]]:
    response = response_for(base, candidate, end_time, print_step)
    GENERATED.mkdir(exist_ok=True)
    (GENERATED / "last_strike_angle_candidate.responses").write_text(response, encoding="ascii")
    root = BASE_PRESET.parents[1]
    report_path = root / "report.txt"
    result_path = root / "result.txt"
    for output in (report_path, result_path):
        try:
            output.unlink()
        except FileNotFoundError:
            pass

    started = time.perf_counter()
    try:
        proc = subprocess.run(
            [str(SIM)],
            input=response,
            text=True,
            cwd=root,
            capture_output=True,
            timeout=timeout,
        )
        timed_out = False
    except subprocess.TimeoutExpired:
        proc = None
        timed_out = True

    row: dict[str, float | int | str | bool] = {
        "release_angle_deg": candidate.release_angle_deg,
        "impact_angle_deg": candidate.impact_angle_deg,
        "direction_deg": candidate.direction_deg,
        "direction2_deg": candidate.direction_deg + 180.0,
        "face_radius": candidate.face_radius,
        "wall_time": time.perf_counter() - started,
        "timed_out": timed_out,
    }

    samples: list[dict[str, float | str]] = []
    if timed_out:
        row.update(
            {
                "end_time": 0.0,
                "exit_status": -999,
                "score": -999.0,
                "step_too_small": False,
                "center_orbit_rms_m": math.nan,
                "center_drift_m": math.nan,
                "center_path_length_m": math.nan,
            }
        )
        return row, samples

    row["process_status"] = proc.returncode if proc is not None else -999
    if not report_path.exists():
        row.update({
            "end_time": 0.0,
            "exit_status": proc.returncode if proc is not None else -995,
            "score": -1.0e9,
            "output_missing": True,
            "skip_reason": "simulator did not write report.txt",
            "last_mode": "no-report",
        })
        return row, samples

    if report_path.exists():
        row.update(parse_report(report_path))
    if result_path.exists():
        samples = parse_timeseries(result_path)
        row.update(parse_result(result_path, motion_ignore_time))
    row["score"] = score_row(row)
    return row, samples


def sample_segments(
    samples: list[dict[str, float | str]],
    row_end: float,
    target_end: float,
    print_step: float,
) -> list[tuple[float, float, str]]:
    if not samples:
        return []

    raw: list[tuple[float, float, str]] = []
    for idx, sample in enumerate(samples):
        t0 = float(sample["time"])
        if idx + 1 < len(samples):
            t1 = float(samples[idx + 1]["time"])
        else:
            t1 = min(row_end, t0 + print_step)
        if t1 <= t0:
            continue
        raw.append((max(0.0, t0), min(target_end, t1), str(sample["mode"]).lower()))

    if not raw:
        return []

    merged: list[tuple[float, float, str]] = [raw[0]]
    for t0, t1, mode in raw[1:]:
        last_t0, last_t1, last_mode = merged[-1]
        if mode == last_mode and abs(t0 - last_t1) <= max(1.0e-9, print_step * 0.51):
            merged[-1] = (last_t0, t1, last_mode)
        else:
            merged.append((t0, t1, mode))
    return merged


def write_plot(
    svg_path: Path,
    rows: list[dict[str, float | int | str | bool]],
    traces: dict[float, list[dict[str, float | str]]],
    end_time: float,
    print_step: float,
    motion_ignore_time: float,
    best_realistic: dict[str, float | int | str | bool] | None,
) -> None:
    row_count = max(len(rows), 1)
    map_height = max(2.4, 0.35 * row_count)
    fig_height = map_height + 4.2
    fig, (ax_map, ax_summary, ax_motion) = plt.subplots(
        3,
        1,
        figsize=(12.5, fig_height),
        gridspec_kw={"height_ratios": [map_height, 1.7, 1.35]},
        constrained_layout=True,
    )

    y_positions = list(range(row_count))
    bar_height = 0.72
    best_angle = None if best_realistic is None else float(best_realistic["direction_deg"])

    for row_idx, row in enumerate(rows):
        angle = float(row["direction_deg"])
        row_end = float(row.get("end_time", 0.0))
        status = int(row.get("exit_status", -999))
        y_range = (row_idx - bar_height / 2.0, bar_height)

        ax_map.broken_barh(
            [(0.0, end_time)],
            y_range,
            facecolors=MODE_COLORS["stopped"],
            edgecolors="none",
        )
        for t0, t1, mode in sample_segments(traces.get(angle, []), row_end, end_time, print_step):
            ax_map.broken_barh(
                [(t0, max(0.0, t1 - t0))],
                y_range,
                facecolors=MODE_COLORS.get(mode, MODE_COLORS["unknown"]),
                edgecolors="none",
            )

        if bool(row.get("timed_out", False)) or status != 1:
            ax_map.broken_barh(
                [(0.0, max(0.2, min(row_end or end_time, end_time)))],
                y_range,
                facecolors="none",
                edgecolors=MODE_COLORS["timed-out"],
                linewidth=1.2,
            )

        if best_angle is not None and abs(angle - best_angle) < 1.0e-9:
            ax_map.scatter(
                [min(row_end, end_time)],
                [row_idx],
                marker="*",
                s=95,
                color="#f28e2b",
                edgecolor="#5a3100",
                linewidth=0.6,
                zorder=5,
            )

        ax_map.text(
            1.01,
            row_idx,
            f"{row_end:.1f}s, status {status}, "
            f"wob {float(row.get('initial_wobble_axis', math.nan)):.3f}, "
            f"orbit {1000.0 * float(row.get('center_orbit_rms_m', math.nan)):.1f} mm",
            transform=ax_map.get_yaxis_transform(),
            va="center",
            fontsize=8.5,
        )

    ax_map.set_xlim(0.0, end_time)
    ax_map.set_ylim(-0.7, row_count - 0.3)
    ax_map.set_yticks(y_positions)
    ax_map.set_yticklabels([f"{float(row['direction_deg']):g}" for row in rows])
    ax_map.set_ylabel("pendulum 1 strike angle [deg]")
    ax_map.set_xlabel("time [s]")
    ax_map.set_title("Strike-angle time map", loc="left", fontsize=14, fontweight="bold")
    ax_map.grid(axis="x", color="#d8d8d8", linewidth=0.8)
    ax_map.set_axisbelow(True)

    legend_items = [
        Patch(facecolor=MODE_COLORS["sliding"], edgecolor="none", label="sliding"),
        Patch(facecolor=MODE_COLORS["rolling"], edgecolor="none", label="rolling"),
        Patch(facecolor=MODE_COLORS["stopped"], edgecolor="none", label="ended"),
        Patch(facecolor="none", edgecolor=MODE_COLORS["timed-out"], label="solver/timeout stop"),
    ]
    ax_map.legend(handles=legend_items, loc="upper right", ncols=4, frameon=False, bbox_to_anchor=(1.0, 1.16))

    angles = [float(row["direction_deg"]) for row in rows]
    lifetimes = [float(row.get("end_time", 0.0)) for row in rows]
    wobbles = [float(row.get("initial_wobble_axis", math.nan)) for row in rows]
    statuses = [int(row.get("exit_status", -999)) for row in rows]
    point_colors = ["#4c78a8" if status == 1 else "#e15759" if status == -3 else "#f28e2b" for status in statuses]

    ax_summary.plot(angles, lifetimes, color="#2f4b7c", linewidth=1.4, alpha=0.65)
    ax_summary.scatter(angles, lifetimes, c=point_colors, s=36, zorder=3)
    ax_summary.axhline(end_time, color="#9c9c9c", linestyle=":", linewidth=1)
    ax_summary.set_xlabel("pendulum 1 strike angle [deg]")
    ax_summary.set_ylabel("run time [s]")
    ax_summary.set_ylim(0.0, max(end_time * 1.05, max(lifetimes, default=0.0) * 1.08))
    ax_summary.grid(axis="both", color="#e2e2e2", linewidth=0.8)
    ax_summary.set_axisbelow(True)

    ax_wobble = ax_summary.twinx()
    ax_wobble.plot(angles, wobbles, color="#8f5da2", linestyle="--", marker=".", linewidth=1.0)
    ax_wobble.set_ylabel("initial wobble/axis [-]")

    if best_realistic is not None:
        ax_summary.scatter(
            [float(best_realistic["direction_deg"])],
            [float(best_realistic.get("end_time", 0.0))],
            marker="*",
            s=125,
            color="#f28e2b",
            edgecolor="#5a3100",
            linewidth=0.6,
            zorder=5,
        )

    orbit_rms_mm = [1000.0 * float(row.get("center_orbit_rms_m", math.nan)) for row in rows]
    drift_mm = [1000.0 * float(row.get("center_drift_m", math.nan)) for row in rows]
    ax_motion.plot(angles, orbit_rms_mm, color="#7f7f7f", linewidth=1.3, marker=".", label="RMS radius")
    ax_motion.plot(angles, drift_mm, color="#c44e52", linewidth=1.1, marker=".", label="drift")
    ax_motion.set_xlabel("pendulum 1 strike angle [deg]")
    ax_motion.set_ylabel("center motion [mm]")
    ax_motion.set_title(
        f"Center motion after {motion_ignore_time:g}s",
        loc="left",
        fontsize=11,
        fontweight="bold",
    )
    finite_motion = [
        value
        for value in orbit_rms_mm + drift_mm
        if math.isfinite(value)
    ]
    if finite_motion:
        motion_top = max(finite_motion)
        ax_motion.set_ylim(0.0, motion_top * 1.12 if motion_top > 0.0 else 1.0)
    ax_motion.grid(axis="both", color="#e2e2e2", linewidth=0.8)
    ax_motion.set_axisbelow(True)
    ax_motion.legend(loc="upper right", frameon=False, ncols=2)

    fig.savefig(svg_path, bbox_inches="tight")
    plt.close(fig)


def complete_key(end_time: float, row: dict[str, float | int | str | bool]) -> tuple[int, float, float]:
    full_run = int(int(row.get("exit_status", -999)) == 1 and float(row.get("end_time", 0.0)) >= end_time - 1.0e-6)
    return (full_run, float(row.get("score", -999.0)), -abs(float(row["direction_deg"])))


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Scan strike direction for one fixed launch setup. Release theta and "
            "impact theta stay fixed unless you override them."
        )
    )
    parser.add_argument("--name", default="strike_angle", help="Output file stem under generated/.")
    parser.add_argument("--angles", default="", help="Explicit comma-separated strike directions in degrees.")
    parser.add_argument("--angle-min", type=float, default=-20.0, help="Minimum strike direction when --angles is omitted.")
    parser.add_argument("--angle-max", type=float, default=0.0, help="Maximum strike direction when --angles is omitted.")
    parser.add_argument("--angle-step", type=float, default=0.5, help="Strike-direction step when --angles is omitted.")
    parser.add_argument("--include-negative", action="store_true", help="Mirror the generated angle range around zero.")
    parser.add_argument("--end-time", type=float, default=None, help="Maximum simulated time. Defaults to the preset value.")
    parser.add_argument("--print-step", type=float, default=0.001, help="Output sampling step passed to the simulator.")
    parser.add_argument("--timeout", type=float, default=20.0, help="Wall-clock seconds before one run is killed.")
    parser.add_argument("--min-realistic-angle", type=float, default=5.0, help="Reference threshold for marking near-grazing hits.")
    parser.add_argument("--motion-ignore-time", type=float, default=2.0, help="Ignore early transient motion before summarizing wobble.")
    parser.add_argument("--release-angle", type=float, default=None, help="Fixed rod release theta in degrees. Defaults to the preset.")
    parser.add_argument("--impact-angle", type=float, default=None, help="Fixed rod impact theta in degrees. Defaults to the preset.")
    parser.add_argument("--face-radius", type=float, default=None, help="Fixed face strike radius. Defaults to the preset.")
    parser.add_argument("--write-best", action="store_true", help="Write the best strike-direction candidate to a response file.")
    args = parser.parse_args()

    stale_reason = simulator_stale_reason()
    if stale_reason:
        print(stale_reason)
        print("Run `cmd /c run.bat --build-only` to rebuild it.")
        return 2

    base = read_base_values(BASE_PRESET)
    end_time = float(args.end_time if args.end_time is not None else base[IDX_END_TIME])
    release_angle = float(args.release_angle if args.release_angle is not None else base[IDX_RELEASE_ANGLE])
    impact_angle = float(args.impact_angle if args.impact_angle is not None else base[IDX_IMPACT_ANGLE])
    radius = float(args.face_radius if args.face_radius is not None else base[IDX_FACE_RADIUS])
    angles = build_angles(args)

    GENERATED.mkdir(exist_ok=True)
    rows: list[dict[str, float | int | str | bool]] = []
    traces: dict[float, list[dict[str, float | str]]] = {}

    for idx, angle in enumerate(angles, 1):
        candidate = Candidate(
            release_angle_deg=release_angle,
            impact_angle_deg=impact_angle,
            direction_deg=angle,
            face_radius=radius,
        )
        row, samples = run_angle(
            base,
            candidate,
            end_time,
            args.print_step,
            args.timeout,
            args.motion_ignore_time,
        )
        rows.append(row)
        traces[angle] = samples
        print(
            f"{idx:3d}/{len(angles)} angle={angle:6.2f} "
            f"end={float(row.get('end_time', 0.0)):7.3f} "
            f"status={row.get('exit_status')} "
            f"wob={float(row.get('initial_wobble_axis', math.nan)):.3f} "
            f"modes={row.get('mode_changes', 0)}"
        )

    rows_by_angle = sorted(rows, key=lambda row: float(row["direction_deg"]))
    realistic = [row for row in rows if abs(float(row["direction_deg"])) >= args.min_realistic_angle]
    best_realistic = max(realistic, key=lambda row: complete_key(end_time, row), default=None)

    safe_name = "".join(ch if ch.isalnum() or ch in "_-" else "_" for ch in args.name).strip("_")
    if not safe_name:
        safe_name = "strike_angle"


    svg_path = GENERATED / f"{safe_name}_time_map.svg"
    write_plot(
        svg_path,
        rows_by_angle,
        traces,
        end_time,
        args.print_step,
        args.motion_ignore_time,
        best_realistic,
    )

    if best_realistic is not None:
        print(
            "\nBest realistic angle "
            f"(abs(angle)>={args.min_realistic_angle:g} deg): "
            f"{float(best_realistic['direction_deg']):g} deg, "
            f"end={float(best_realistic.get('end_time', 0.0)):.3f}, "
            f"status={best_realistic.get('exit_status')}"
        )

    if args.write_best and best_realistic is not None:
        best_candidate = Candidate(
            release_angle_deg=float(best_realistic["release_angle_deg"]),
            impact_angle_deg=float(best_realistic["impact_angle_deg"]),
            direction_deg=float(best_realistic["direction_deg"]),
            face_radius=float(best_realistic["face_radius"]),
        )
        best_response = response_for(base, best_candidate, end_time, float(base[IDX_PRINT_STEP]))
        best_path = GENERATED / "best_realistic_angle.responses"
        best_path.write_text(best_response, encoding="ascii")
        run_angle(
            base,
            best_candidate,
            end_time,
            float(base[IDX_PRINT_STEP]),
            args.timeout,
            args.motion_ignore_time,
        )
        shutil.copy2(BASE_PRESET.parents[1] / "report.txt", GENERATED / "best_realistic_angle_report.txt")
        shutil.copy2(BASE_PRESET.parents[1] / "result.txt", GENERATED / "best_realistic_angle_result.txt")
        print(f"Wrote {best_path}")

    print(f"Wrote {svg_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
