# PipePin Native ARKit 0.5.2 — Ray-Lock + Frozen Coordinates

Focused accuracy correction after the 0.5.1 on-device screen recording.

## What changed

- **Reticle ray is now the placement authority.** LiDAR depth is projected along RealityKit's exact `ARView.ray(through:)` ray through the visible centre crosshair, rather than rebuilding the 3D point from camera intrinsics.
- **Aim validation before commit.** The calculated 3D point is projected back to screen. If it is more than 14 px away from the reticle, PipePin rejects the pin instead of drawing a beam in the wrong place.
- **Capture spread validation.** Ten-frame precision captures with more than 55 mm spread are rejected as unstable.
- **Live 3D aim probe.** A tiny green/white world-space point shows where PipePin currently believes the reticle lands. It should sit under the crosshair before a precision pin is accepted.
- **Saved service XYZ is immutable.** ARKit anchor refinements are now used only as drift diagnostics. They no longer drag the visible beam or overwrite the saved service coordinate.
- **Much tighter drift tripwire.** A service anchor shift above 25 mm frame-to-frame or 50 mm from its saved position freezes/hides beams and marks the site position unsafe.
- **World-position jump detection.** A physically impossible camera-coordinate jump above 300 mm between frames freezes the beams.
- **No silent recovery after integrity loss.** Once a position shift/jump is detected, the app keeps beams hidden until a deliberate Site Map re-lock.
- **Saved map positions stay frozen.** Saving a Site Map no longer writes ARKit-adjusted anchor coordinates back over the original service pin coordinates.

## Test order

1. Open one site and slowly scan until `PRECISION READY`.
2. Aim at a distinctive point 0.5–2 m away. Confirm the tiny green/white 3D aim probe appears under the orange crosshair.
3. Create one vertical precision pin. Its centre sphere should appear exactly at the aimed point.
4. Move sideways in the same room. The beam should remain attached to the original physical point.
5. Save the Site Map.
6. Walk toward/through a doorway slowly while continuing to scan. If PipePin detects a coordinate shift, it should **hide the beam**, not move it.
7. Use Re-lock to Site Map before trusting the beam again.

Artifact: `PipePinAR-0.5.2-iPhone-build`
IPA: `PipePinAR-0.5.2-unsigned.ipa`
