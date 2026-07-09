# RDFT Chladni Sphere Synth

This is a performance-focused variant of the current HOLO Drive RDFT synth.
The synthesis engine and data model remain the same:

- Processing still computes the RDFT field, orbit dynamics, Phi residual, holonomy, Berry/Floquet metrics, galaxy/surface coupling, MIDI pilot, and environmental bridge state.
- SuperCollider still receives the same OSC messages in `ColdSun_Shimmer.scd`, especially `/rdf/field`, `/rdf/orbit`, `/rdf/surface`, `/rdf/mix`, `/rdf/egProbe`, `/rdf/floquet_*`, `/rdf/solar`, and `/rdf/ocean`.
- The Chladni Sphere UI only changes the playable surface: controls are moved, the dense panel stack is bypassed, and the main display now emphasizes a large sphere driven by the active SuperCollider layer mix.

## Launch

From this folder:

```bash
./start_chladni_mac.sh
```

That opens Processing on this sketch folder and SuperCollider on `ColdSun_Shimmer.scd`, and starts the same optional solar, ocean, galaxy, and surface bridge processes when available.

To stop the background senders:

```bash
./stop_chladni_mac.sh
```

## Play Surface

- Left rail: the original five core RDFT diagnostic panels are kept as square, non-distorted mini panels.
- Main sphere: combines the live `combined` RDFT field, SuperCollider layer waveforms, the action orbit, and surface/geometry overlays.
- Right rail: run/reset/hold/sweep, holonomy controls, output/reverb/action sensitivity, layer toggles, Floquet spawn/kill, and surface geometry controls.
- Bottom strip: field parameters, root frequency, scale/modulation selectors, audio layer levels, ocean/solar controls, recording, and Berry reset.
- Sphere interaction: click inside the sphere to reposition the action orbit; the orbit continues to drive the existing `/rdf/orbit` synthesis path.

## Novation Launchpad X

- Plug the Launchpad X in before launching the sketch. The MIDI pilot now prefers `Launchpad X`, `Launchpad`, or `Novation` devices before generic USB keyboards.
- On this Mac, CoreMIDI exposes the controller as `LPX MIDI Out/In` and `LPX DAW Out/In`, while Processing's bundled OpenJDK may only see software MIDI devices. The included `launchpad_bridge.swift` routes CoreMIDI Launchpad events into Processing over OSC on port `12000`.
- Grid pads are translated into a playable isomorphic MIDI layout and feed the existing scalar/poly MIDI path. Turn on `POLY` in the synth to play the SuperCollider poly layer from the pads.
- The 8 grid rows act as RDFT performance preset slots: foundation/action, drone, arp, surface-solar-ocean, glass, choir, keys/Hopf, and ECO/EG.
- Common Launchpad function controls map to transport/actions: run, reset, hold, sweep, poly, Floquet on/off, Berry reset, holonomy run/reverse/orient/stop, lag/freeze, and surface/location.
- Optional Launchpad custom-mode CC faders `1..16` control output, reverb, action, layer volumes, ECO levels, EG, ocean current/swell, and solar volume.

## Design Notes

The current full interface is powerful but heavy because it draws many panels, lower bands, image panels, and dense diagnostics every frame. This variant keeps the physics and sound path alive while reducing the main visual workload to the panels that are most playable.

The central visual uses the attached mockups as the target direction, but the second pass is narrower and more vertical: square RDFT side panels, a dominant sphere interface, and controls grouped by function.

## Theory Hooks Preserved

- RDFT field equation residual `F = phi + 1/2 |grad phi|^2 + A exp(-2 phi) S`.
- Local alpha/depth as recursive resolution controls.
- Landauer/coherence surface coupling through `/rdf/surface`.
- Holonomy/Berry loop instrumentation.
- Floquet drive and lifecycle messages.
- SuperCollider-derived layer weights from `/rdf/audioDiag`: drone, arp, glass, choir, rhythm complexity, and eco event pulses are folded into the Chladni surface.
- Hopfield-like recurrent state behavior through the existing recursive field/cache/orbit feedback rather than a separate neural-net rewrite.
