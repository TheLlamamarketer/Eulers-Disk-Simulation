#!/usr/bin/env python3
"""Plot heatmaps from a double-pendulum direction/face-angle sweep CSV."""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import BoundaryNorm, ListedColormap
from matplotlib.patches import Patch


ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "generated"


def as_float(row: dict[str, str], name: str, default: float = math.nan) -> float:
    value = row.get(name, "")
    if value is None or value == "":
        return default
    try:
        number = float(value)
    except ValueError:
        return default
    return number if math.isfinite(number) else default


def as_bool(row: dict[str, str], name: str) -> bool:
    return str(row.get(name, "")).strip().lower() in {"1", "true", "yes", "y"}


def nearly_equal(a: float, b: float, tol: float = 1.0e-9) -> bool:
    return abs(a - b) <= tol


def maybe_filter(rows: list[dict[str, str]], name: str, value: float | None) -> list[dict[str, str]]:
    if value is None:
        return rows
    return [row for row in rows if nearly_equal(as_float(row, name), value)]


def cell_status(row: dict[str, str]) -> int:
    if as_bool(row, "skipped_physical") or not as_bool(row, "physical_hit"):
        return 0
    if as_bool(row, "lost_contact"):
        return 1
    if as_bool(row, "step_too_small") or as_bool(row, "timed_out"):
        return 2
    exit_status = int(as_float(row, "exit_status", -999.0))
    if exit_status not in (0, 1):
        return 2
    return 3


def center_edges(values: list[float]) -> np.ndarray:
    centers = np.array(values, dtype=float)
    if len(centers) == 1:
        return np.array([centers[0] - 0.5, centers[0] + 0.5])
    mids = (centers[:-1] + centers[1:]) / 2.0
    first = centers[0] - (mids[0] - centers[0])
    last = centers[-1] + (centers[-1] - mids[-1])
    return np.concatenate([[first], mids, [last]])


def best_rows_by_cell(rows: list[dict[str, str]]) -> dict[tuple[float, float], dict[str, str]]:
    cells: dict[tuple[float, float], dict[str, str]] = {}
    for row in rows:
        direction = as_float(row, "direction_deg")
        phi = as_float(row, "face_angle_deg")
        if not (math.isfinite(direction) and math.isfinite(phi)):
            continue
        key = (direction, phi)
        old = cells.get(key)
        if old is None or as_float(row, "score", -1.0e300) > as_float(old, "score", -1.0e300):
            cells[key] = row
    return cells


def matrix_for(
    cells: dict[tuple[float, float], dict[str, str]],
    directions: list[float],
    phis: list[float],
    column: str,
    scale: float = 1.0,
) -> np.ndarray:
    data = np.full((len(phis), len(directions)), np.nan)
    for j, phi in enumerate(phis):
        for i, direction in enumerate(directions):
            row = cells.get((direction, phi))
            if row is not None:
                data[j, i] = scale * as_float(row, column)
    return data


def status_matrix(
    cells: dict[tuple[float, float], dict[str, str]],
    directions: list[float],
    phis: list[float],
) -> np.ndarray:
    data = np.full((len(phis), len(directions)), np.nan)
    for j, phi in enumerate(phis):
        for i, direction in enumerate(directions):
            row = cells.get((direction, phi))
            if row is not None:
                data[j, i] = cell_status(row)
    return data


def plot_panel(ax, x_edges, y_edges, data, title, cbar_label, cmap="viridis", vmin=None, vmax=None):
    masked = np.ma.masked_invalid(data)
    mesh = ax.pcolormesh(x_edges, y_edges, masked, shading="auto", cmap=cmap, vmin=vmin, vmax=vmax)
    ax.set_title(title, loc="left", fontsize=11, fontweight="bold")
    ax.set_xlabel("strike direction 1 [deg]")
    ax.set_ylabel("face angle phi 1 [deg]")
    ax.grid(color="#ffffff", linewidth=0.35, alpha=0.55)
    ax.set_axisbelow(False)
    cbar = ax.figure.colorbar(mesh, ax=ax, shrink=0.92)
    cbar.set_label(cbar_label)
    return mesh


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", nargs="?", default=str(GENERATED / "double_pendulum_sweep.csv"))
    parser.add_argument("--output", default=None)
    parser.add_argument("--mass", type=float, default=None)
    parser.add_argument("--release", type=float, default=None)
    parser.add_argument("--radius", type=float, default=None)
    args = parser.parse_args()

    csv_path = Path(args.csv_path)
    if not csv_path.is_absolute():
        csv_path = ROOT / csv_path
    if args.output:
        output_path = Path(args.output)
        if not output_path.is_absolute():
            output_path = ROOT / output_path
    else:
        output_path = csv_path.with_name(csv_path.stem + "_heatmap.svg")

    with csv_path.open(newline="", encoding="utf-8") as fp:
        rows = list(csv.DictReader(fp))

    rows = maybe_filter(rows, "mass", args.mass)
    rows = maybe_filter(rows, "release_deg", args.release)
    rows = maybe_filter(rows, "face_radius", args.radius)
    if not rows:
        raise SystemExit("No rows left after filters.")

    cells = best_rows_by_cell(rows)
    directions = sorted({key[0] for key in cells})
    phis = sorted({key[1] for key in cells})
    x_edges = center_edges(directions)
    y_edges = center_edges(phis)

    end_time = matrix_for(cells, directions, phis, "end_time")
    score = matrix_for(cells, directions, phis, "score")
    score = np.where(score > 0, score, np.nan)
    wobble = matrix_for(cells, directions, phis, "initial_wobble_axis")
    orbit_mm = matrix_for(cells, directions, phis, "center_orbit_rms_m", scale=1000.0)
    theta_excess = matrix_for(cells, directions, phis, "theta_excess_rate")
    status = status_matrix(cells, directions, phis)

    fig, axs = plt.subplots(2, 3, figsize=(16, 8.5), constrained_layout=True)
    plot_panel(axs[0, 0], x_edges, y_edges, end_time, "Lifetime", "seconds", cmap="magma")
    plot_panel(axs[0, 1], x_edges, y_edges, score, "Score", "higher is better", cmap="viridis")
    plot_panel(axs[1, 0], x_edges, y_edges, wobble, "Initial Wobble / Axis", "ratio", cmap="plasma")
    plot_panel(axs[1, 1], x_edges, y_edges, orbit_mm, "Center Orbit RMS", "mm", cmap="cividis")
    plot_panel(axs[1, 2], x_edges, y_edges, theta_excess, "Theta Excess Rate", "rad/sample", cmap="inferno")

    status_cmap = ListedColormap(["#d0d0d0", "#d95f02", "#b2182b", "#1b9e77"])
    status_norm = BoundaryNorm([-0.5, 0.5, 1.5, 2.5, 3.5], status_cmap.N)
    axs[0, 2].pcolormesh(
        x_edges,
        y_edges,
        np.ma.masked_invalid(status),
        shading="auto",
        cmap=status_cmap,
        norm=status_norm,
    )
    axs[0, 2].set_title("Outcome", loc="left", fontsize=11, fontweight="bold")
    axs[0, 2].set_xlabel("strike direction 1 [deg]")
    axs[0, 2].set_ylabel("face angle phi 1 [deg]")
    axs[0, 2].grid(color="#ffffff", linewidth=0.35, alpha=0.55)
    axs[0, 2].legend(
        handles=[
            Patch(facecolor="#d0d0d0", label="not physical"),
            Patch(facecolor="#d95f02", label="lost contact"),
            Patch(facecolor="#b2182b", label="solver stop"),
            Patch(facecolor="#1b9e77", label="valid"),
        ],
        loc="upper right",
        frameon=False,
        fontsize=8,
    )

    for ax in axs.flat:
        ax.set_xticks(directions)
        ax.set_yticks(phis)
        ax.tick_params(axis="x", labelrotation=45)

    fig.suptitle(csv_path.name, fontsize=14, fontweight="bold")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
