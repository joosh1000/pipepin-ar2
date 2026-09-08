# PipePin Native ARKit 0.6.1 — Map Lock + Power

Focused correction after on-device 0.6 testing.

## Why 0.6 could look as if the map had not saved

0.6 saved the raw LiDAR mesh first and only then asked ARKit for an `ARWorldMap`. The first archive could succeed even if the relocalisation map failed. More importantly, changing MAP/PIN/LOCATE re-ran the AR configuration every time, which could cause scene-reconstruction anchors to be rebuilt. A saved pin could then appear to move with the revised world estimate.

## 0.6.1 changes

- **Transactional Save + Lock:** `SAVED ✓` is shown only after both the ARWorldMap and LiDAR mesh are written and immediately read back successfully.
- **No fake persistence:** if old service pins exist but the matching world map is missing/corrupt, the pins stay hidden rather than being interpreted in a brand-new AR origin.
- **Explicit relocalisation:** saved Sites open in low-power LOCATE mode. Beams remain hidden until ARKit has restored the saved map and PipePin reports `SITE LOCKED ✓`.
- **MAP ↔ PIN no longer restarts the AR session.** This removes a major source of unnecessary mesh rebuilding and coordinate adjustment.
- **Lens is locked after the first service pin.** Camera-format changes are not allowed to disturb a pinned Site.
- **Lower-power spatial pipeline:** continuous `sceneDepth` + `smoothedSceneDepth` have been removed from normal operation. The LiDAR scene mesh is the primary precision surface and AR raycast is the fallback.
- **30 fps cap in every mode**, with a sensible ~1080p-class video format rather than always selecting the largest stream.
- **No environment-texture capture** because PipePin does not need it.
- **App-side diagnostics/health checks throttled to ~15 Hz** instead of driving SwiftUI from every AR frame.
- **X-Ray automatically hides after a verified save** because drawing the full mesh costs GPU/battery.
- **Thermal state** is shown in the mapping/tools UI.

## Recommended test order

1. Start a fresh test Site for 0.6.1.
2. Stay in MAP and scan one room + doorway until the map says extending/mapped.
3. Switch MAP → PIN and confirm the existing mesh does not visibly restart.
4. Place one service pin.
5. Switch PIN → MAP and press **SAVE + LOCK MAP**.
6. Do not leave the Site until the button/status says **SAVED ✓**.
7. Leave the Site and open it again.
8. It should open in LOCATE/relocalisation mode. Existing beams must remain hidden until **SITE LOCKED ✓**.
9. Once locked, check the original beam against the physical point.
10. Compare battery use over 10 minutes in MAP and 10 minutes in LOCATE. MAP will still be the heaviest mode; LOCATE should be materially lighter.

## Important current limitation

The raw 3D LiDAR mesh is now reliably persisted for the future 3D model, but 0.6.1 still uses ARKit's `ARWorldMap` to restore the live coordinate system. The next spatial-model step is rendering/using the saved mesh itself as a persistent site geometry layer instead of only retaining it as model data.

Artifact: `PipePinAR-0.6.1-iPhone-build`
IPA: `PipePinAR-0.6.1-unsigned.ipa`
