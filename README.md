# PipePin Native ARKit 0.2 — LiDAR + Service Types

This is the second native iPhone proof-of-concept build.

## What's new in 0.2

- Proper app-style full-screen AR interface.
- Centre targeting crosshair rather than accidental tap-anywhere placement.
- Select what you're marking: Pipe, Cable, Joist, Duct, Drain, Gas, Structure, Fixing or Other.
- Pins are colour-coded by service type.
- LiDAR scene reconstruction is enabled automatically when supported.
- Mesh classification is requested on supported LiDAR devices.
- Scene depth / smoothed scene depth is enabled when available.
- RealityKit scene-understanding occlusion, collision and lighting are enabled.
- Scan screen shows whether LiDAR is active and how many mesh/plane anchors are currently mapped.
- Toggle the LiDAR mesh wireframe on/off to see what the phone is actually reconstructing.
- Saved pins screen has service icons and a selected-pin locate mode.
- Horizontal and vertical offset card retained for the floor-to-floor experiment.
- Haptic feedback on successful/failed placement.

## Important scope note

The service type is manually selected in 0.2. LiDAR maps the physical geometry; it does not automatically know that a particular cylinder is a water pipe or that a ceiling member is a joist. Automatic recognition is a possible later computer-vision/ML phase.

## Build on GitHub

Upload the contents of this folder to the root of the existing `pipepin-ar` GitHub repository and commit the changes. The included GitHub Actions workflow will build an unsigned physical-device IPA.

Actions -> Build PipePin iPhone IPA -> Run workflow

Download artifact `PipePinAR-0.2-iPhone-build`, extract `PipePinAR-0.2-unsigned.ipa`, then install it with Sideloadly as before.

## First LiDAR test

1. Open PipePin and move around the room slowly for 10–20 seconds.
2. Open **Scan** and confirm it says **LiDAR Available / active** if the device supports it.
3. Tap **Show LiDAR mesh**. You should see a depth-coloured wireframe over reconstructed room surfaces.
4. Hide the mesh again.
5. Select **Pipe**, aim the crosshair at a pipe and press **Mark Pipe**.
6. Repeat for a cable/joist/other feature.
7. Walk around and check that the pins remain fixed in world space.
8. Select a pin from **Pins** to see horizontal/vertical offset for locating above/below it.

## Next experiments after 0.2

- Persistent ARWorldMap/building scan so pins survive app relaunches with spatial relocalisation.
- Multi-point service route tracing (a line/path, not just a single point).
- Better floor-to-floor above/below guidance.
- LiDAR room/floor mesh capture and export.
- Building/project hierarchy.
- Automatic service recognition research.
