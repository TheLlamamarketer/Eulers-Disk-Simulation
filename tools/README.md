# Tool Guide

Use this file first when the tool names feel too similar.

| File | Use it when you want to... | Parameters it varies |
| --- | --- | --- |
| `launch_parameter_search.py` | Find mirrored launch settings that keep the disk alive longer. It runs the simulator for each candidate and writes end time, score, and diagnostics to a CSV. | Release theta and impact theta by default. Direction, radius, and face angle stay at the preset unless you pass their options. |
| `strike_angle_scan.py` | Inspect one fixed release/impact setup across strike directions and see the time/contact-mode map. | Strike direction only, unless you pass a different fixed release/impact theta. |
| `launch_search_heatmap.py` | Replot an existing `launch_parameter_search.py` CSV. | Nothing new; it filters and visualizes existing rows. |
| `launch_model.py` | Shared helper code used by the search and scan tools. | Do not run directly. |
| `pendulum_rod.py` | Check the physical rod pendulum calculation by release theta and impact theta. | Release theta and impact theta. |
| `score_paired_impulse_grid.py` | Quickly score impulse geometry without running the full simulator. | Geometry-only grid settings. |
| `show_paired_impulse_geometry.py` | Draw one paired-impulse geometry diagnostic. | One geometry setup. |

So for your release-theta / impact-theta question, start with:

```powershell
py -3 tools\launch_parameter_search.py --release-angles -55:-45:2.5 --impact-angles 35:55:5
```

If you do not want to type commands, double-click `search_launch_parameters.bat`
from the repo root and edit its `ARGS` line when you want a different range.
Leave `--directions`, `--radii`, and `--face-angles` out unless you explicitly
want a geometry search.

`strike_angle_scan.py` is for the follow-up question: once release and impact
theta are fixed, which strike direction gives the cleanest run over time?
