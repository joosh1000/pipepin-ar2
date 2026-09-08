# PipePin Native 0.6 — Spatial Site Map

This build pivots PipePin from floating AR anchors toward the Magic-Room-style architecture: **the LiDAR building mesh is the site model, and services are placed into that same spatial world.**

## Core changes

- **MAP / PIN / LOCATE modes**
  - **MAP** runs LiDAR scene reconstruction and shows the live depth-coloured X-RAY mesh.
  - **PIN** keeps the mesh active and returns to the normal 1× wide camera for precision targeting.
  - **LOCATE** backs off continuous scene reconstruction/depth processing to reduce battery and heat while navigating to saved services.
- **Mesh-locked service placement**
  - RealityKit scene-understanding collision is enabled.
  - The exact centre-reticle ray is cast against the reconstructed LiDAR mesh.
  - When the UI shows **MESH HIT**, the service is placed on that scanned building surface and stored as `Spatial mesh` rather than a guessed plane.
  - LiDAR depth and AR plane raycast remain fallbacks where the mesh has not reached a target yet.
- **3D Site Map snapshot**
  - `SAVE 3D MAP` now archives the current `ARMeshAnchor` geometry for the selected Site as well as saving the `ARWorldMap` used for relocalisation.
  - Mesh anchor / vertex / face counts are shown in Precision & Mapping.
  - This raw mesh archive is the foundation for the future rotatable 3D building/service model. 0.6 does not yet rebuild a standalone mesh viewer from the archive.
- **X-RAY mode**
  - Shows RealityKit's live depth-coloured scene-understanding wireframe, similar to the spatial-mesh concept seen in the Vision Pro reference video.
- **Less trigger-happy position uncertainty**
  - `LOCKED` = high confidence.
  - `CAUTION` = tracking weakened but saved service coordinates stay frozen and beams remain visible.
  - `LOST` = only a major coordinate jump, severe anchor divergence, interruption, or sustained tracking failure hides the beams.
- **Stable Auto torch**
  - Darkness has to persist for about a second before Auto turns the torch on.
  - Once Auto turns it on, it stays latched on instead of using its own increased light reading to turn itself back off and pulse.
- **Experimental 0.5× mapping view**
  - If ARKit exposes an ultra-wide world-tracking video format on the iPhone, MAP mode can test 0.5× to keep more walls/ceiling/floor/door geometry in view in tight spaces.
  - PIN mode automatically returns to 1× for the precision placement step.
  - If the ultra-wide format is incompatible with the active LiDAR configuration on the device, PipePin falls back to 1×.
- **Battery/thermal work**
  - MAP and LOCATE prefer supported 30 fps formats.
  - PIN can use the higher-rate wide-camera format for the short precision task.
  - LOCATE removes continuous mesh/depth semantics from its configuration.

## First test order

1. Open a Site and stay in **MAP**.
2. Scan one room slowly until the wireframe covers walls, floor and ceiling. Include the doorway and some of the next room.
3. If **0.5×** is available, try the same route once at Auto/1× and once at 0.5×. The goal is to see which maintains tracking better when close to walls and through doors.
4. Tap **SAVE 3D MAP** after a useful area has been scanned.
5. Switch to **PIN**. The camera should use the precision wide view. Aim at a clear pipe/corner. Prefer placing when the deck says **MESH HIT**.
6. Create a vertical beam and check that its centre lands at the crosshair position.
7. Walk through a doorway. A brief tracking drop should now become **CAUTION** while the beam remains fixed/visible; it should not immediately disappear.
8. Switch to **LOCATE**, choose the saved service from Pins and compare battery/heat behaviour with MAP mode.
9. Test Auto torch in a dark area. It should turn on after sustained darkness and stay on rather than pulse.

## What this build does not claim yet

- A saved raw mesh is not yet re-rendered as an offline standalone 3D building viewer.
- The saved mesh is not yet used for custom ICP/geometry matching against a later live scan; ARKit `ARWorldMap` still handles live relocalisation in 0.6.
- Multi-point pipe/cable route tracing comes after we prove the building mesh and room-to-room coordinate stability are useful.

Build artifact: `PipePinAR-0.6-iPhone-build`

IPA: `PipePinAR-0.6-unsigned.ipa`
