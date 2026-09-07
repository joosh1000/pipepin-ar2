# PipePin Native ARKit 0.1 — Windows → iPhone free test route

This project is designed so the source can live on a Windows PC, GitHub supplies a temporary macOS build machine, and Sideloadly signs/installs the resulting IPA onto your own iPhone with a free Apple Account.

## What this build is testing

The only goal of this build is to prove **real ARKit world anchoring**:

1. Open PipePin on the iPhone.
2. Slowly scan the room until tracking says **good**.
3. Tap a physical corner, wall point, pipe or other visible surface.
4. Walk/turn around.
5. The marker should stay in the same 3D world position instead of following the phone screen.
6. If that works, keep the app open and walk upstairs to test the floor-to-floor position.

This is native ARKit/RealityKit, not browser/PWA visual tracking.

---

## Part A — free Apple registration

1. Go to https://developer.apple.com/register/ in a browser.
2. Sign in with an Apple Account.
3. Accept the Apple Developer Agreement.
4. **Do not buy the paid Apple Developer Program yet.** Free registration is enough for this personal-device test.

Free signing normally expires after 7 days, so the test app needs to be refreshed/reinstalled periodically.

---

## Part B — build the unsigned IPA with GitHub

1. Create/sign in to a GitHub account.
2. Create a new **private** repository, e.g. `pipepin-ar`.
3. Upload the **contents of this folder** to the repository. Make sure `.github/workflows/build-unsigned-ipa.yml` is included.
4. Open the repository's **Actions** tab.
5. Choose **Build PipePin iPhone IPA**.
6. Press **Run workflow**.
7. Wait for the green tick.
8. Open the completed workflow run and download the artifact called **PipePinAR-iPhone-build**.
9. Extract the downloaded artifact ZIP. Inside is `PipePinAR-unsigned.ipa`.

The GitHub build does not need your Apple ID or signing certificate. It only compiles the iPhone app on a macOS runner.

---

## Part C — install from Windows with Sideloadly

Sideloadly is a third-party sideloading tool, not an Apple product. If you would rather not use your main Apple Account in third-party software, use a separate Apple Account dedicated to development/testing.

1. Download Sideloadly for Windows from https://sideloadly.io/.
2. Follow its Windows prerequisites. Its current instructions recommend Apple's web-download versions of iTunes and iCloud rather than the Microsoft Store versions.
3. Connect the iPhone to the PC with USB.
4. Unlock the iPhone and press **Trust** when it asks whether to trust the computer.
5. Open Sideloadly. Your iPhone should appear in the device selector.
6. Drag `PipePinAR-unsigned.ipa` into Sideloadly.
7. Enter the Apple Account you want to use for free signing.
8. Press **Start** and complete Apple's two-factor-authentication prompt if requested.
9. Wait for Sideloadly to report that installation completed.

---

## Part D — allow the development app on iPhone

Depending on the iOS version, you may need both of these:

### Developer Mode

`Settings → Privacy & Security → Developer Mode → On`

The iPhone normally restarts and asks you to confirm Developer Mode after reboot.

### Trust the developer profile

If iOS shows **Untrusted Developer**:

`Settings → General → VPN & Device Management → [Apple Account used for signing] → Trust`

Then launch **PipePinAR** from the Home Screen and allow camera access.

---

## First physical test

Use an obvious corner or detailed fixed feature.

1. Scan the room for 10–20 seconds.
2. Wait for `Tracking: good`.
3. Tap the exact corner/point.
4. A native 3D marker should appear there.
5. Move 1–2 metres sideways while keeping the point visible.
6. Turn until the marker leaves the screen.
7. Turn back.
8. Check whether the marker returns to the physical point rather than staying at a fixed screen coordinate.
9. Walk around the room and approach it from another angle.

If that behaves correctly, the next test is **pin downstairs → walk upstairs without closing PipePin → locate the X/Z position above it**.

## Free-account limitation

Apple's free Personal Team provisioning is temporary. Apple currently documents 7-day expiry for free App IDs, devices and provisioning profiles. Re-sign/reinstall with the same Apple Account and bundle ID to continue testing.
