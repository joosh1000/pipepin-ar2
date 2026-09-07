# PipePin AR roadmap

## Phase 0 — prove the positioning idea
Goal: determine whether phone-only AR tracking is accurate enough to locate a point through a floor.

Success test:
- Pin a downstairs point.
- Walk upstairs without resetting tracking.
- Find the projected X/Z location.
- Compare against the true point.
- Record error over multiple runs and buildings.

Decision bands (working targets, not promises):
- < 10 cm repeatedly: excellent; proceed quickly.
- 10–25 cm: useful for many tracing jobs; improve with reference points.
- 25–50 cm: possibly useful as a coarse locator; reference-point correction likely required.
- > 50 cm / frequent tracking loss: add stronger localisation before building features around it.

## Phase 1 — trade-ready tracing tool
- Marker types: pipe, cable, drain, duct, valve, unknown.
- Custom names and notes.
- Draw multi-point routes, not just single pins.
- Above/below mode with direction + distance.
- Job and building folders.
- Photos attached to markers.
- Accuracy/confidence indicator.
- Undo/edit/delete.

## Phase 2 — persistence and drift correction
- Save ARWorldMap / local spatial map where supported.
- Re-open a building and relocalise.
- Place permanent reference markers at known points.
- QR / visual reference anchors for rapid correction.
- Floor levels and room labels.
- Recalibrate position at any known reference point.

## Phase 3 — building scan
- LiDAR room/mesh capture on supported iPhones/iPads.
- Floor/wall/ceiling geometry.
- Service routes overlaid on the building mesh.
- Measurements and clearances.
- Export/share building model.

## Phase 4 — digital twin
- Full building → floor → room → asset/service model.
- Service history and inspection records.
- “What is behind this wall/floor?” view.
- Collaboration between trades.
- Change history / as-built revisions.
- Potential AssetTrak integration for assets and maintenance records.
