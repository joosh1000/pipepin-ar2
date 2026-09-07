# PipePin Native ARKit 0.4 — Sites + Directional Beams

Native iPhone ARKit / RealityKit prototype.

## Added in 0.4

- Site-first home screen: create/select a building or job before entering AR.
- Site name, optional address and Job ID/reference stored locally on the iPhone.
- Service pins are grouped by site.
- Existing 0.3.x test pins are migrated to the first site opened after installing 0.4.
- Vertical and horizontal service beam modes.
- Horizontal beam direction is captured from the phone's screen-left/screen-right axis at the moment the pin is placed.
- Optional direction metadata: No arrows / Up or Down for vertical runs / Forward or Reverse for horizontal runs.
- Repeated white chevron arrows are rendered along directional beams.
- Stronger service colours, beam halo and target glow.
- 6 m / 12 m / 20 m locator beam lengths remain available.
- LiDAR mesh debug view remains available on supported iPhones.

## Important prototype limitation

Site grouping is now persistent, but a full persistent AR world map / LiDAR building model is not implemented yet. ARKit world coordinates can move between fresh AR sessions. The next mapping phase should save/relocalize a site's spatial map before treating old service coordinates as permanent survey data.

## Install / build

Copy this folder over the cloned GitHub repository using GitHub Desktop, commit and push. The included GitHub Action builds:

`PipePinAR-0.4-unsigned.ipa`

Install it with Sideloadly using the same free Apple developer test workflow as previous builds.
