# MacBook FaceID

Face Unlock for Mac — a notch-native scan that watches for you, then types the password you saved.

This is a convenience feature built around the built-in (or external) webcam. It is **not** TrueDepth Face ID, it does **not** use the Secure Enclave, and it is **not** a security upgrade.

**Site:** [plut0000.github.io/MacBook-FaceID](https://plut0000.github.io/MacBook-FaceID/) (GitHub Pages). Download, setup, and privacy notes live there; binaries stay on [GitHub Releases](https://github.com/plut0000/MacBook-FaceID/releases/latest).

**Minimum OS:** macOS 14 Sonoma (Apple silicon or Intel). The island sits in the hardware notch on 14″ / 16″ MacBook Pro and notched MacBook Air. On a Mac without a notch, a floating pill appears at the top of the display.

## Read this first

A Mac webcam sees a **flat 2D image**. iPhone Face ID builds a 3D depth map. That means:

- Heavy liveness can reject a printed photo or a still image on a phone screen with reasonable confidence.
- It does **not** reliably defeat a video of you.
- macOS has no API that lets a third-party app authorize a login, so this app unlocks by **typing your stored password** at the lock screen (Accessibility).

Only continue if you accept that tradeoff. Do not use this on a shared Mac you do not control.

## Download

1. Open the latest [GitHub Release](https://github.com/plut0000/MacBook-FaceID/releases).
2. Download `MacBook-FaceID.dmg` or `MacBook-FaceID.zip`.
3. Drag **MacBook FaceID** to Applications.
4. First launch: right-click → **Open** (CI builds are unsigned unless you notarize them). Or:

   ```bash
   xattr -cr "/Applications/MacBook FaceID.app"
   open "/Applications/MacBook FaceID.app"
   ```

A release is published when a version tag such as `v0.2.0` is pushed.

## Permissions

| Permission | Why |
| --- | --- |
| **Camera** | See your face. Frames are processed in memory and are not written to disk. |
| **Accessibility** | Type the saved password into the lock-screen field. |
| **Touch ID / device password** | Gates the AES key in Keychain that encrypts embeddings and the login password (`userPresence`). |

There is no telemetry and no network requirement.

## Setup

1. Launch the app and read the warning. Allow **Camera** and **Accessibility**.
2. Authorize a session with Touch ID (or your device password). That creates or unwraps the vault key.
3. Enter your Mac login password once. It is stored encrypted, never as plaintext on disk.
4. Enroll: the app walks you through **nine head directions**. Each accepted frame becomes a 512-number embedding; the image is discarded.
5. When the Mac locks or wakes (and optionally when you press space at the lock screen), the island expands and scans. A match that also passes liveness types the password.

You can enroll more identities later (glasses, beard, lighting) and toggle any of them off without deleting.

## How unlock works

An unlock requires **all** of the following:

1. A Face Unlock session is authorized (key in memory).
2. The Mac is actually at the lock screen.
3. An **enabled** identity matches above the similarity threshold.
4. Liveness accepts the face (unless liveness is off).
5. Accessibility is available to type the password.

### Triggers

Pick any combination in Settings → Recognition:

- On lock
- On wake
- Space bar at the lock screen (listen-only; space still reaches macOS)

### Exact behavior (honest)

| Situation | What happens |
| --- | --- |
| Screen lock / screen saver after you are already logged in | Island scans; on match + liveness, types the vault password. |
| Display asleep | The app asserts local user activity to wake the panel, then types. You may still need one lid/key/trackpad wake if the password field is not up yet. |
| Lid closed | The camera cannot see you. |
| FileVault / EFI pre-boot, or the login window before any user session | **Cannot unlock.** The app only runs inside an existing user session. |
| Fast User Switching / another user’s login window | **Not supported.** |
| Session auto-locked after idle | Face may match, but the password is not typed until you authorize again. |
| Wrong saved password | One attempt, then **Unlock failed**. Update it in Settings → Password. |
| Island on the lock wallpaper | The panel uses a high window level and *tries* to stay visible. Unlock can still proceed if animations are hidden or the lock UI covers the island. |

### Notch UI

A closed pill in the notch (or a floating pill on notchless Macs) expands into a scan with success and failure. Hover to retry after a failure. You can hide animations entirely in General — watching still runs. Scan style is **Minimal** or **Classic** (cosmetic only). Hovering the island can fire trackpad haptics.

### Recognition

Default engine: an original **512-d embedding** of a 112×112 aligned face (DCT + local binary pattern + pose-normalized landmarks), compared with cosine similarity. Apple’s older face-print request is gone from current SDKs; this project does **not** bundle anyone else’s ArcFace `.mlpackage`.

Optional: drop a redistributable Core ML face-embedding model at:

```
~/Library/Application Support/MacBookFaceID/FaceEmbedder.mlmodel
```

(or `.mlpackage`). The first image-like input and the first multi-array output are used. Re-enroll after adding a model. A public MobileFaceNet / InsightFace conversion you license yourself is appropriate; do not copy proprietary app models.

### Liveness (original)

Rolling window of about two seconds:

- **Deny cues** (Light and Heavy): screen-like glare; a device-shaped rectangle around the face. Either fails the scan.
- **Confirm cues** (Heavy only): blink, nose parallax across small head motion, 3D-ish landmark geometry. Any one is enough. Their absence is not a failure in Light, because a live person can sit still.

Modes: Light, Heavy, Off.

### Credentials

Embeddings and the login password live in an AES-256-GCM vault under Application Support. The 256-bit key is in the login Keychain, access-controlled with `userPresence`. The key is held in memory only while a session is authorized and is dropped after the idle interval you choose.

## Settings

Simple panes rather than a dense dump:

- **Your Face** — identities, enable/disable, enroll another, delete
- **Recognition** — triggers, similarity threshold, liveness
- **Camera** — built-in vs external display cameras
- **Password** — create or replace the encrypted login password
- **General** — enable, login item, haptics, hide animations, scan style, session auto-lock, About

Click the app icon in About five times for a small probe readout (last similarity and liveness reason).

## Privacy

- Camera frames are not written to disk. Enrollment keeps embeddings, not photos.
- The vault is encrypted. Erase in General removes the vault files and the Keychain key immediately.
- No analytics, accounts, or cloud sync.

## Build from source (Xcode)

Xcode 15+ on a Mac. Deployment target is macOS 14.

```bash
git clone https://github.com/plut0000/MacBook-FaceID.git
cd MacBook-FaceID
open MacBookFaceID/MacBookFaceID.xcodeproj
```

Select the **MacBookFaceID** scheme, destination **My Mac**, and Run.

```bash
xcodebuild \
  -project MacBookFaceID/MacBookFaceID.xcodeproj \
  -scheme MacBookFaceID \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .derived \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The project is notarization-ready (Hardened Runtime, camera entitlement) but **not sandboxed**. App Sandbox blocks the Accessibility + Keychain unlock path.

Optional: regenerate the Xcode project with `python3 scripts/generate_xcodeproj.py` (or [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`).

## Building a release

```bash
git tag v0.2.0
git push origin v0.2.0
```

GitHub Actions (`macos-latest`) builds Release, packs a zip, and on `v*` tags also a zlib DMG. Pull requests upload zip only (not the whole `dist/` tree).

## Architecture

| Module | Role |
| --- | --- |
| **App** | SwiftUI lifecycle, `AppModel` |
| **Island** | Notch / floating-pill `NSPanel`, scan animation |
| **Enrollment** | Nine-pose capture, images discarded |
| **Recognition** | Align, 512-d embed, encrypted identities |
| **Liveness** | Light / Heavy / Off spoof cues |
| **Credentials** | AES-GCM vault, Keychain `userPresence`, idle session |
| **Unlock** | Lock/wake/space triggers, Accessibility typing |
| **Settings** | Your Face, Recognition, Camera, Password, General |

Product feel is inspired by public Face Unlock Mac apps (notch pill, multi-pose enroll, session-gated password). The SwiftUI implementation, animations, liveness math, and embedding pipeline are original to this repository.

## Security caveats

- Convenience unlock, not biometric auth bound to the Secure Enclave.
- 2D embeddings can be fooled by look-alikes, video, or a similar face in good light.
- A process running as you, with an authorized session and Accessibility, can type the same password.
- Grant Accessibility only if you accept that this app can post keyboard events.
