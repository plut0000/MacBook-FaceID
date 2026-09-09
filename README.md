# MacBook FaceID

Convenience **Face Unlock** for MacBooks with a notch (2021+). The app lives in the notch (Dynamic Island / Boring Notch style), enrolls your face with the built-in camera, and types your saved macOS login password when the live face matches.

This is **not** TrueDepth Face ID and it does **not** use the Secure Enclave. Treat it as a convenience feature for a Mac you own — not as a security boundary.

**Minimum OS:** macOS 13 Ventura (Apple silicon or Intel). Notch placement is designed for 14″ / 16″ MacBook Pro and notched MacBook Air. On Macs without a notch, controls appear as a menu-bar extra.

## Download

1. Open the latest [GitHub Release](https://github.com/plut0000/MacBook-FaceID/releases).
2. Download `MacBook-FaceID.dmg` or `MacBook-FaceID.zip`.
3. Open the disk image (or unzip) and drag **MacBook FaceID** to Applications.
4. First launch: right-click the app → **Open** (CI builds are unsigned unless you notarize them yourself). You can also run:

   ```bash
   xattr -cr "/Applications/MacBook FaceID.app"
   open "/Applications/MacBook FaceID.app"
   ```

A release artifact is published automatically when a version tag such as `v0.1.0` is pushed (see [Building a release](#building-a-release)).

## Permissions

The app asks for three things. All three are required for unlock to work.

| Permission | Why |
| --- | --- |
| **Camera** | Enroll your face and watch for a match. Frames stay on this Mac. |
| **Accessibility** | After a match, inject the password into the lock-screen field (`CGEvent`). Enable **MacBook FaceID** in System Settings → Privacy & Security → Accessibility. |
| **Keychain** | Your macOS login password is stored in the login keychain (`After First Unlock`, this device only). It is never written to a file. |

There is no telemetry and no network requirement.

## Setup

1. Launch **MacBook FaceID**. First run opens a short setup sheet.
2. Allow **Camera** and **Accessibility**.
3. Enter your **macOS login password** twice. It is saved only in Keychain.
4. Sit in good light, look at the camera, and enroll. The app keeps several Vision landmark embeddings plus a local thumbnail.
5. On a notched Mac, hover the notch to expand the panel. Enable **Face Unlock** if it is off. Optionally turn on **Open at login**.

Re-enroll and password updates live in the compact Settings sheet (face preview, a few toggles — not a dense preferences window).

## How unlock works

1. **Enroll** — `VNDetectFaceLandmarksRequest` and `VNDetectFaceCaptureQualityRequest` build a local landmark embedding (eyes aligned, unit inter-ocular distance) under `~/Library/Application Support/MacBookFaceID/`.
2. **Watch** — When the screen locks (or the screen saver starts), the camera starts. Live embeddings are compared with RMS distance. A match needs a distance ≤ 0.12, or ≤ 0.075 for an immediate match, with two consecutive hits to reduce accidents.
3. **Unlock** — On match, the password is read from Keychain and typed with Accessibility (`CGEvent` unicode + Return), the same pattern used by popular Mac face-unlock utilities.

### Exact behavior (honest)

| Situation | What happens |
| --- | --- |
| Screen lock / screen saver after you are already logged in | App starts the camera, and if your face matches it types the Keychain password into the lock field. |
| Display asleep | The app asserts local user activity to wake the panel, then types. If macOS has not shown the password field yet, you may need to wake the display (lid, key, trackpad) once; watching resumes on display wake. |
| Lid closed | The camera cannot see you. Nothing happens until the lid is open. |
| FileVault / EFI pre-boot, or the login window before any user session | **Cannot unlock.** The app only runs inside an existing user session. |
| Fast User Switching / another user’s login window | **Not supported.** |
| Wrong saved password | One attempt, then status **Unlock failed**. Update the password in Settings. |
| Notch UI on the lock wallpaper | The panel uses a high window level and *tries* to stay visible; some macOS versions still hide app windows on the lock surface. Unlock can still proceed without the animation. |

Animation style is cosmetic only:

- **Minimal** — modern iPhone-like ring and check.
- **Classic** — iPhone X–era concentric scan rings.

Copy in the UI says **Face Unlock**, not Face ID, except for the app name.

## Security caveats

- This is **convenience unlock**, not biometric authentication bound to Secure Enclave.
- Vision landmark embeddings can be fooled by look-alikes, photos, or a similar face in good light. Thresholds trade false unlocks against missed unlocks.
- The login password exists in Keychain so the app can type it. A process running as you, with Keychain and Accessibility access, can do the same.
- Grant Accessibility only if you accept that this app can post keyboard events.
- Do not use this on a shared Mac you do not control.

## Build from source (Xcode)

You need Xcode 15+ on a Mac.

```bash
git clone https://github.com/plut0000/MacBook-FaceID.git
cd MacBook-FaceID
open MacBookFaceID/MacBookFaceID.xcodeproj
```

Select the **MacBookFaceID** scheme, destination **My Mac**, and Run.

Or from the command line:

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

open ".derived/Build/Products/Release/MacBook FaceID.app"
```

The project is notarization-ready (Hardened Runtime, camera entitlement) but **not sandboxed**. App Sandbox blocks the Accessibility + Keychain unlock path these utilities need.

Optional: regenerate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.

## Building a release

Push a tag to publish a `.dmg` and `.zip` on GitHub Releases (GitHub Actions, `macos-latest`):

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow also runs on pull requests (build + artifact, no release) and can be started manually from the Actions tab.

To sign and notarize, replace the ad-hoc `CODE_SIGN_IDENTITY="-"` in CI with your Developer ID and notarization secrets. Unsigned builds require right-click **Open**.

## Architecture

| Module | Role |
| --- | --- |
| **App** | SwiftUI lifecycle, `AppModel`, first-run windows |
| **NotchUI** | Notch `NSPanel`, Minimal/Classic animation, settings, menu-bar fallback |
| **Camera / Vision** | AVFoundation capture, enrollment, local templates |
| **Unlock** | Lock/screensaver observers, display wake, Accessibility typing |
| **Keychain** | Login password in the macOS Keychain |

## Privacy

- Face templates and the optional thumbnail stay in Application Support on this Mac.
- The login password stays in Keychain.
- Settings → **Erase enrollment & password** removes both.
- No analytics, accounts, or cloud sync.
