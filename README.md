# PipePin Native ARKit 0.5.1 — Aim + Stability Fix

Focused correction to the 0.5 Precision Mapping build after on-device testing.

## Fixed

- **Crosshair and AR target are now the same point.** In 0.5 the visible reticle sat inside a VStack between the header and controls, while ARKit/LiDAR always sampled the geometric centre of the ARView. The reticle is now independently overlaid at that exact centre.
- **LiDAR centre-depth is calibrated with the AR camera intrinsics.** Depth is unprojected into world space rather than assuming the optical forward vector is exactly the image centre.
- **No automatic ARWorldMap archive after every pin.** Site maps can be large with LiDAR scene reconstruction; they are now saved only from the explicit Save Site Map control.
- World-map saves cannot overlap.
- Reference snapshots cannot overlap and use lower JPEG memory.
- Torch switching is debounced to avoid repeatedly reconfiguring the camera while ARKit is active.
- AR session errors are surfaced in the HUD and beams are hidden rather than left looking trustworthy.

## First test

1. Open a site and wait for Precision Ready.
2. Aim the **white centre dot** at a small, obvious physical feature.
3. Precision Pin it.
4. Without moving much, verify the centre sphere appears on the same physical feature.
5. Repeat at 0.5 m, 1 m, 2 m and 3 m if possible.
6. Then test walking away / room transitions.

If the app exits to the Home Screen again, retrieve the iOS crash report from **Settings → Privacy & Security → Analytics & Improvements → Analytics Data** and send the newest `PipePin...` or `JetsamEvent...` entry. `JetsamEvent` usually indicates iOS killed the app for memory pressure.

Artifact: `PipePinAR-0.5.1-iPhone-build`
IPA: `PipePinAR-0.5.1-unsigned.ipa`
