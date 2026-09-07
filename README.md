# PipePin Native ARKit 0.3.1 — Force Update

This package contains the premium UI + long vertical locator beam build.

## Important
The GitHub repository previously had `project.yml` updated to 0.3, but the Swift source files remained from 0.2. That is why the built app looked unchanged.

## Recommended update method
Use GitHub Desktop on Windows so files are actually overwritten:

1. Install GitHub Desktop and sign in.
2. File -> Clone repository -> choose `joosh1000/pipepin-ar2`.
3. Open the local repository folder.
4. Copy everything from this package into that local folder and choose **Replace the files in the destination**.
5. In GitHub Desktop you should see changes to `ContentView.swift`, `ARSessionController.swift`, `Marker.swift`, `project.yml`, and the workflow.
6. Commit to `main`, then Push origin.
7. Run the GitHub Action.

## How to confirm the correct source is installed
The app header visibly shows `0.3.1`. The main AR screen uses the premium dark HUD and the selected pin has a long vertical service beam.

Artifact: `PipePinAR-0.3.1-iPhone-build`
IPA: `PipePinAR-0.3.1-unsigned.ipa`
