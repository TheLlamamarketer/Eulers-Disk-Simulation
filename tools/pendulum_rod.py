#!/usr/bin/env python3
"""Physical rod pendulum helper used by the disk strike initializer."""

from __future__ import annotations

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.patches import Rectangle
from matplotlib.transforms import Affine2D
from scipy.integrate import solve_ivp


GRAVITY = 9.8067e3  # mm/s^2
ROD_LENGTH = 750.0
ROD_WIDTH = 25.0
TOP_OFFSET = 12.5
PIVOT_TO_TIP = 737.5
PIVOT_TO_CENTER = 360.5

DENSITY = 2.7e-3
VOLUME = 146379.5
MASS = DENSITY * VOLUME

INITIAL_THETA = -np.pi / 4.0 - 0.1
IMPACT_THETA = np.pi / 4.0
INITIAL_OMEGA = 0.0
TIME_SPAN = (0.0, 5.0)

I_CM = np.diag([17686.075, 22.646, 17704.504]) * 1000.0
I_ZZ = I_CM[2, 2] + MASS * PIVOT_TO_CENTER**2
GRAVITY_FACTOR = -MASS * GRAVITY * PIVOT_TO_CENTER / I_ZZ

MASS_KG = MASS / 1000.0
PIVOT_TO_CENTER_M = PIVOT_TO_CENTER / 1000.0
PIVOT_TO_TIP_M = PIVOT_TO_TIP / 1000.0
I_ZZ_KG_M2 = I_ZZ * 1.0e-9


def contact_point(theta: float) -> np.ndarray:
    return PIVOT_TO_TIP * np.array([np.sin(theta), -np.cos(theta), 0.0])


def physical_pendulum_impact(
    release_theta: float,
    impact_theta: float,
    direction: float = 0.0,
    restitution: float = 0.0,
) -> dict[str, float]:
    """Return rod impact values for angles in radians.

    `direction` is the world-frame impulse direction. The effective mass is
    computed along that direction, so it changes with the impact angle.
    """

    angle_drop = np.cos(impact_theta) - np.cos(release_theta)
    if angle_drop < 0.0:
        raise ValueError("release angle does not have enough height to reach impact angle")

    lever_arm = PIVOT_TO_TIP_M * np.cos(impact_theta - direction)
    if abs(lever_arm) <= 1.0e-12:
        raise ValueError("impact direction gives a zero pendulum lever arm")

    angular_speed = np.sqrt(2.0 * MASS_KG * 9.8067 * PIVOT_TO_CENTER_M * angle_drop / I_ZZ_KG_M2)
    normal_speed = abs(angular_speed * lever_arm)
    effective_mass = I_ZZ_KG_M2 / lever_arm**2
    impulse = (1.0 + restitution) * effective_mass * normal_speed
    return {
        "angular_speed": float(angular_speed),
        "normal_speed": float(normal_speed),
        "effective_mass": float(effective_mass),
        "lever_arm": float(lever_arm),
        "impulse": float(impulse),
    }


def pendulum_rhs(_time: float, state: np.ndarray) -> np.ndarray:
    theta, omega = state
    return np.array([omega, GRAVITY_FACTOR * np.sin(theta)])


def angle_event(target_angle: float, *, terminal: bool = False):
    def event(_time: float, state: np.ndarray) -> float:
        return state[0] - target_angle

    event.terminal = terminal
    event.direction = 0
    return event


def solve_motion():
    return solve_ivp(
        pendulum_rhs,
        TIME_SPAN,
        np.array([INITIAL_THETA, INITIAL_OMEGA]),
        events=angle_event(IMPACT_THETA, terminal=True),
        dense_output=True,
        max_step=1.0e-3,
    )


def calculate_impact(solution) -> None:
    impact_time = solution.t_events[0][0]
    theta_hit, omega_hit = solution.sol(impact_time)
    impact = physical_pendulum_impact(INITIAL_THETA, theta_hit)

    print(f"Impact time: {impact_time:.6f} s")
    print(f"Impact angle: {theta_hit:.6f} rad")
    print(f"Impact angular velocity: {omega_hit:.6f} rad/s")
    print(f"Normal impact speed: {impact['normal_speed']:.6f} m/s")
    print(f"Effective mass at contact: {impact['effective_mass']:.6f} kg")
    print(f"Estimated normal impulse: {impact['impulse']:.6f} Ns")


def animate(solution) -> None:
    display_fps = 120
    animation_end_time = float(solution.t[-1])
    duration = max(animation_end_time - TIME_SPAN[0], 1.0e-9)
    frame_count = max(2, int(duration * display_fps))
    omega_max = np.max(np.abs(solution.y[1]))
    velocity_scale = 1.0 / omega_max if omega_max != 0.0 else 1.0

    fig, ax = plt.subplots()
    ax.set_xlim(-800, 800)
    ax.set_ylim(-800, 800)
    ax.set_aspect("equal")
    ax.grid()

    line, = ax.plot([], [], "o-", lw=2)
    rod = Rectangle(
        (-ROD_WIDTH / 2.0, -TOP_OFFSET),
        ROD_WIDTH,
        ROD_LENGTH,
        color="blue",
        alpha=0.5,
    )
    ax.add_patch(rod)
    velocity_arrow = ax.quiver([0], [0], [0], [0], angles="xy", scale_units="xy", scale=1, color="red")

    def init():
        line.set_data([], [])
        rod.set_transform(Affine2D().rotate(INITIAL_THETA + np.pi) + ax.transData)
        velocity_arrow.set_offsets(np.array([[0, 0]]))
        velocity_arrow.set_UVC([0], [0])
        return line, rod, velocity_arrow

    def update(sim_time):
        theta, omega = solution.sol(sim_time)
        line.set_data([0, PIVOT_TO_CENTER * np.sin(theta)], [0, -PIVOT_TO_CENTER * np.cos(theta)])
        rod.set_transform(Affine2D().rotate(theta + np.pi) + ax.transData)

        tip_x = PIVOT_TO_TIP * np.sin(theta)
        tip_y = -PIVOT_TO_TIP * np.cos(theta)
        velocity_arrow.set_offsets(np.array([[tip_x, tip_y]]))
        velocity_arrow.set_UVC(
            [omega * PIVOT_TO_TIP * np.cos(theta) * velocity_scale],
            [omega * PIVOT_TO_TIP * np.sin(theta) * velocity_scale],
        )
        return line, rod, velocity_arrow

    animation = FuncAnimation(
        fig,
        update,
        frames=np.linspace(TIME_SPAN[0], animation_end_time, frame_count),
        init_func=init,
        interval=1000.0 * duration / frame_count,
        blit=True,
        repeat=True,
    )
    _ = animation
    plt.show()


def main() -> None:
    solution = solve_motion()
    calculate_impact(solution)
    animate(solution)


if __name__ == "__main__":
    main()
