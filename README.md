# PipePin Native ARKit 0.1 — free Windows test build

Native SwiftUI + ARKit + RealityKit proof of concept for PipePin.

Start with **START-HERE-WINDOWS.md**.

The included GitHub Actions workflow compiles an unsigned iPhone IPA on a GitHub-hosted macOS runner. The IPA can then be signed and installed onto the owner's iPhone from Windows using a free Apple Account and a compatible sideloading tool.

Core proof: place a real ARKit world-space marker, move around the room, and verify that it remains attached to the physical location rather than the screen.
