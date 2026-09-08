# PipePin Native ARKit 0.5 — Precision Mapping

Accuracy-first native iPhone test build.

## New in 0.5

- Precision Pin no longer relies on a single AR raycast when LiDAR depth is available.
- Centre-reticle LiDAR depth sampling uses a confidence-filtered patch and collects 10 stable frames before committing a pin.
- Low-confidence depth, fast phone movement, poor tracking and low-light states block precision capture instead of silently creating a questionable pin.
- Continuous torch control: Auto / On / Off.
- Explicit ARKit service anchors are added for pinned services.
- Site ARWorldMap can be saved, loaded and used for re-lock/relocalisation.
- Existing service beams are hidden whenever tracking is considered unreliable rather than continuing to show a confidently wrong position.
- Site hierarchy now includes Floor + Room mapping areas; new pins are tagged to the active area.
- Reference snapshot is stored locally when a precision pin is created.
- Accuracy Test: return to the original physical point, aim at it again and measure the 3D error in millimetres.
- Diagnostics expose tracking, world-map state, LiDAR depth/confidence, motion speed, low light and interruption/re-lock counts.
- Existing 0.4.1 fixes remain: no unwanted extra Locate target; horizontal beams use the rear camera's forward direction.

## First test sequence

1. Select/create a Site.
2. Tap the Floor/Room label in the AR header and choose/create an area.
3. Slowly scan the room until `PRECISION READY` appears.
4. In **Precision & Mapping**, leave Torch on Auto and confirm LiDAR confidence reaches 1/2 or 2/2 on the target.
5. Aim at a known service point and tap **PRECISION PIN**. Hold still while the 10-frame capture completes.
6. Save/update the Site Map once the room is mapped well.
7. Walk into another room/floor. If tracking becomes uncertain, PipePin should hide service beams instead of moving them.
8. Use **Re-lock to saved Site Map**, scan recognisable surroundings and wait for the beams to reappear.
9. Return to the original physical point and use **Accuracy Test** to record the error in millimetres.

## Important prototype limitation

0.5 materially improves capture quality and relocalisation behaviour, but it does not turn an iPhone into survey equipment. The purpose of this build is to measure how much drift remains across rooms/floors and determine whether phone-only positioning is accurate enough for the PipePin use case.

Build artifact: `PipePinAR-0.5-iPhone-build`
IPA: `PipePinAR-0.5-unsigned.ipa`
