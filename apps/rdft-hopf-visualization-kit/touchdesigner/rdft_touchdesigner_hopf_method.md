# RDFT Hopf / Hyperobject TouchDesigner Method

This is the TouchDesigner version of the RDFT Hopf manifold visualization.

The PyGFX route is better for quick scientific inspection. TouchDesigner is better for turning the same geometry into an audiovisual stage object: bloom trails, instancing, feedback, camera moves, TOP compositing, and live performance control.

## What this uses

The included `rdft_touchdesigner_script_sop_callbacks.py` file creates a geometry polyline from your RDFT CSV.

It supports three views:

| View | Meaning | CSV variables |
|---|---|---|
| `base` | direct Hopf base trajectory | `hopf_base_x`, `hopf_base_y`, `hopf_base_z` |
| `phase` | phase-derived Hopf projection | `hopf_fiber_phase`, `hopf_thread_phase`, `found_coherence`, `floquet_lock_gated`, `hopf_link_proxy` |
| `winding` | winding-space transit | `hopf_fiber_winding`, `hopf_thread_winding`, `hopf_activity_proxy` |

The phase view is the closest to the “beyond 3D” idea. It treats the fiber/thread phases as a projected Hopf map from an abstract \(S^3\)-like state down into visible 3D.

## Basic TouchDesigner network

Create this network:

```text
script_sop_hopf
  -> null_sop_hopf
  -> geo_hopf

camera1
light1
geo_hopf
  -> render1 TOP
  -> bloom TOP / feedback TOP / level TOP
  -> out1 TOP
```

Inside `geo_hopf`, point the SOP parameter to `null_sop_hopf`.

## Setup steps

1. Open TouchDesigner.
2. Create a **Script SOP**.
3. Open the Script SOP’s docked callback DAT.
4. Paste the full contents of `rdft_touchdesigner_script_sop_callbacks.py`.
5. Edit this line near the top:

```python
CSV_PATH = "/ABSOLUTE/PATH/TO/osc_state_2026-06-15_08-20-12.csv"
```

6. Choose the view:

```python
VIEW = "phase"
```

Use one of:

```python
VIEW = "base"
VIEW = "phase"
VIEW = "winding"
```

7. Connect the Script SOP to a Null SOP.
8. Put that Null SOP inside or into a Geometry COMP.
9. Add Camera, Light, Render TOP.
10. Add bloom/feedback/composite effects after Render TOP.

## Recommended visual treatment

For the look you’re describing, use TouchDesigner’s strengths:

### Geometry layer

Use the Script SOP output as a **spine**.

Then add:

```text
script_sop_hopf
  -> resample SOP
  -> trail SOP
  -> null SOP
```

If the curve is too jagged, insert a **Resample SOP** or **Filter SOP**.

### Particle/point layer

To make the transit feel alive:

```text
script_sop_hopf
  -> sop_to_chop
  -> geometry instancing
```

Then instance small spheres, sprites, or points along the curve.

Good instancing controls:

- Translate X/Y/Z from SOP-derived point positions.
- Scale from `hopf_activity_proxy` if you add it as a CHOP channel later.
- Color from time index or winding value.

### Feedback layer

A strong visual chain:

```text
render1 TOP
  -> level TOP
  -> bloom TOP
  -> feedback TOP
  -> composite TOP
  -> out TOP
```

Use feedback very lightly. This should feel like a coherent transit wake, not fog.

## Making it dynamic

The current Script SOP creates the full curve at once.

For an animated “moving through the manifold” version, there are two easy options:

### Option 1 — Use a Carve SOP

Add:

```text
script_sop_hopf
  -> carve SOP
  -> null SOP
```

Animate the Carve SOP’s second U parameter with:

```python
absTime.seconds * 0.05 % 1
```

That reveals the curve as a moving transit.

### Option 2 — Animate MAX_POINTS / slice index in Python

Inside the Script SOP callback, replace:

```python
rows = _downsample(rows, MAX_POINTS)
```

with a time-window slice based on `absTime.frame`.

This gives you a traveling segment instead of the whole manifold.

## Best view for the current 06/15 run

Start with:

```python
VIEW = "phase"
MAX_POINTS = 1800
SCALE = 8.0
CLOSED = False
```

That should give you the closest TouchDesigner equivalent to the phase-derived Hopf projection from the PyGFX script.

## Honest interpretation

The TouchDesigner graph is a projection, not proof of literal four-dimensional structure.

But because the CSV already contains Hopf base/fiber/thread variables, this is not arbitrary sci-fi geometry either. It is a legitimate geometric rendering of the logged transit state, especially when using the `phase` and `winding` views.

The best mental model:

> The RDFT run is being treated as a high-dimensional state path. TouchDesigner renders a visible projection of that path as a fibered transit object.
