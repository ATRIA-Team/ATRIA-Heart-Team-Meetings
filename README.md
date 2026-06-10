![ATRIA Banner](assets/GitHub%20banner%20ATRIA.png)

# ATRIA Heart Team Meetings for Apple Vision Pro

> A spatial, multi-participant visionOS meeting tool developed to help the Heart Team define the best strategical decision and approach to a cardiac surgery.

---

## Table of Contents

- [Overview](#overview)
- [Platform Requirements](#platform-requirements)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
  - [Model-View pattern](#model-view-pattern)
  - [AppStore](#appstore)
  - [Window topology](#window-topology-visionos)
- [SharePlay & Real-Time Sync](#shareplay--real-time-sync)
  - [Message types](#message-types)
  - [Message flow](#message-flow)
- [DICOM Decoding](#dicom-decoding)
- [App Walkthrough](#app-walkthrough)
  - [1 - Home](#1--home)
  - [2 - Lobby: Loading Patient Files](#2--lobby-loading-patient-files)
  - [3 - Session Start: Shared Window & Remote Controls](#3--session-start-shared-window--remote-controls)
  - [4 - Shared Window: Medical Documents](#4--shared-window-medical-documents)
  - [5 - Shared Window: CT Scan](#5--shared-window-ct-scan)
  - [6 - Annotation: Local Canvas](#6--annotation-local-canvas)
  - [7 - Annotation: Drawing](#7--annotation-drawing)
  - [8 - Annotation: Shared on the Meeting](#8--annotation-shared-on-the-meeting)
  - [9 - Full Session View](#9--full-session-view)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Clone and open](#clone-and-open)
- [Testing](#testing)
- [macOS Companion App](#macos-companion-app)
- [Debug Flags](#debug-flags)
- [Contributing](#contributing)
  - [Branch strategy](#branch-strategy)
  - [Opening a Pull Request](#opening-a-pull-request)
  - [Commit messages](#commit-messages)
  - [What not to include in a PR](#what-not-to-include-in-a-pr)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Overview

ATRIA enables medical teams to review diagnostic imaging studies together in mixed reality. Multiple clinicians wearing Apple Vision Pro can join a shared session and simultaneously explore patient's clinical information, CT scans with slice navigation, window/level adjustments, and take together annotations that are synchronized in real time across all participants, allowing for a collaborative environment.

A companion macOS app allows users to organize patient files into structured `.atria` packages that can be shared on iCloud and then loaded directly into a session started on Apple Vision Pro.

**Key capabilities:**
- Real-time DICOM slice viewing synchronized across participants via SharePlay
- 3D spatial drawing with RealityKit in a mixed-reality immersive space
- 2D annotation with any spatial stylus (normalized strokes synced to peers)
- Support for CT, Echo, and Coronary Angiography exam types
- Offline DICOM visualizer
- `.atria` package format for bundling a full patient exam for transport
- macOS companion app for organizing and uploading patient files to iCloud

<br>

<div align="center">
  <table border="0" cellspacing="0" cellpadding="16">
    <tr>
      <td align="center">
        <img src="assets/icons/App%20Icon%20visionOS.png" width="120" alt="ATRIA visionOS icon"/>
        <br/><sub><b>visionOS</b></sub>
      </td>
      <td align="center">
        <img src="assets/icons/App%20Icon%20macOS.png" width="120" alt="ATRIA macOS icon"/>
        <br/><sub><b>macOS</b></sub>
      </td>
    </tr>
  </table>
</div>

---

## Platform Requirements

| Target | Platform | Minimum OS |
|---|---|---|
| `ATRIA` (visionOS) | Apple Vision Pro | visionOS 26.0 |
| `ATRIAmac` (macOS) | Mac | macOS 26.2 |

**SharePlay features require a real visionOS device**. Not all the features of the app can be tested in the simulator: since most of the flow requires the participants to be in a FaceTime call, the simulator is not the ideal environment to test the app. 

---

## Project Structure

```
ATRIA/
├── ATRIA.xcodeproj              # Xcode project (two targets)
├── ATRIA/                       # visionOS app source
│   ├── App/                     # Entry point, AppStore, DebugFlags
│   ├── Stores/                  # Domain stores (viewer, session, annotation, drawing, document)
│   ├── Views/                   # SwiftUI views and UI components
│   ├── Services/                # DICOMImporter, ICloudFolderManager
│   ├── SharePlay/               # GroupActivities coordinator and message types
│   ├── Drawing/                 # 3D RealityKit immersive drawing
│   └── Annotation/              # 2D PencilKit annotation + SwiftData persistence
├── ATRIAmac/                    # macOS companion app source
│   ├── Stores/                  # FolderStore
│   └── Services/                # FolderOrganiser (actor), AtriaArchive
├── ATRIATests/                  # visionOS unit tests
├── ATRIAmacTests/               # macOS unit tests
└── Packages/
    ├── DICOM-Decoder/           # Local Swift package: DicomCore library
    └── RealityKitContent/       # RealityKit scene assets
```

---

## Architecture

### Model-View pattern

The app follows an **MV (Model-View)** pattern. There are no ViewModels as `@Observable` stores replace that layer. Views read state directly from injected stores and call action methods on them.

```
Views  ──calls──▶  AppStore  ──coordinates──▶  Domain Stores
                                                ├── ViewerStore
                                                ├── SessionStore
                                                ├── AnnotationStore
                                                ├── DrawingStore
                                                └── DocumentStore
```

### AppStore

`AppStore` (`ATRIA/App/AppStore.swift`) is the single source of truth injected via `.environment(store)` at the root. It composes five domain stores and exposes cross-cutting action methods so that views call one method and `AppStore` coordinates affected stores internally.

| Store | Owns |
|---|---|
| `store.viewer` | DICOM exam bundles, selected exam, windowing preset, loading/error state |
| `store.session` | SharePlay session lifecycle, participant state, drawing active flag |
| `store.annotation` | 2D annotation sessions and strokes |
| `store.drawing` | 3D brush settings, stroke history, undo/redo |
| `store.document` | Local file URLs, shared window exam type, shared PDF scroll state |

`AppStore` also owns `ICloudFolderManager` (`store.iCloud`) and the private `DICOMImporting` service.

### Window topology (visionOS)

| Scene ID | Content |
|---|---|
| (main) | `RootView` → `HomeView3` or `LobbyView` based on session state |
| `"sharedWindow"` | Shared hub visible to all participants |
| `"remoteControls"` | Local remote-control panel |
| `"annotation"` | 2D Apple Pencil Pro canvas, keyed by session UUID |
| `"drawingTools"` | Floating brush controls |
| `"htmlViewer"` | HTML file display |
| `"pdfViewer"` | PDF viewer (PDFKit, 1600×1200) |
| `"DrawingSpace"` (ImmersiveSpace) | Mixed-immersion 3D stylus drawing |

---

## SharePlay & Real-Time Sync

ATRIA uses Apple's **GroupActivities** framework to synchronize state across participants. **No pixel data or file contents cross the wire** since all the contents of the meeting is cached locally by downloading the `.atria` file package from iCloud. Each participant loads their own local copy of exam files. The app also allows participants to upload manually all the files that are required for the meeting, without needing the `.atria` package.

### Message types

| Type | Transport | Purpose |
|---|---|---|
| `DICOMSyncMessage` | Reliable | Slice changes, preset, session start, shared window, PDF scroll, annotations |
| `DrawPointMessage` | Best-effort | 3D brush stroke points (~10 ms interval) |
| `Annotation2DPointMessage` | Best-effort | 2D annotation points (normalized to [0, 1]) |

### Message flow

```
User action
    │
    ▼
AppStore method call
    │
    ▼
SharePlayCoordinator.send(_:)  ──broadcasts──▶  Remote peers
    │                                                │
    │ (isApplyingRemoteChange prevents echo)         ▼
    │                                    SharePlayCoordinator.apply(_:from:)
    │                                                │
    │                                                ▼
    │                                    SessionStore.applyMessage(_:)
    │                                                │
    │                                                ▼
    │                                    Domain store (viewer / document / annotation)
    ▼
UI updates
```

---

## DICOM Decoding

The `DicomCore` library (`Packages/DICOM-Decoder/`) handles all DICOM file parsing.

**Entry point:** `DCMDecoder`
```swift
let decoder = DCMDecoder()
decoder.setDicomFilename(url.path)
guard decoder.dicomFileReadSuccess else { ... }
let pixels = decoder.getPixels16()  // or getPixels8()
```

**Windowing:**
```swift
let image = DCMWindowingProcessor.applyWindowLevel(
    pixels16: rawBuffer,
    center: preset.center,
    width: preset.width
)
```

**Supported extensions:** `.dcm`, `.dicom`, `.ima`, extensionless.  
Files within a folder are sorted by DICOM Instance Number (tag `0x00200013`).  
Window/level priority: DICOM header → `calculateOptimalWindow()` → user-selected preset.

Raw 16-bit buffers are retained in `DICOMExamBundle.rawPixelBuffers16` so presets can be re-applied without re-reading files from disk.

---

## App Walkthrough

A step-by-step visual guide through the main flows of ATRIA.

> Screenshots go in `assets/screenshots/`. Drop the files there and the images below will render automatically on GitHub.

---

### 1 - Home

The entry point of the app. From here the user can open the offline DICOM visualizer, browse saved annotations, or start a new meeting.

| Home | Offline DICOM Viewer | Annotations |
|:---:|:---:|:---:|
| ![Home view](assets/screenshots/01-home.png) | ![Offline DICOM visualizer](assets/screenshots/02-dicom-viewer.png) | ![Saved annotations](assets/screenshots/03-annotations.png) |

---

### 2 - Lobby: Loading Patient Files

Before starting a meeting, the host uploads the patient's files. This can be done in two ways: loading a pre-packaged `.atria` file from iCloud, or uploading each category of files manually.

| Load .atria Package | Upload Files Manually |
|:---:|:---:|
| ![Load .atria package](assets/screenshots/04-lobby-atria-package.png) | ![Manual file upload](assets/screenshots/05-lobby-manual-upload.png) |

Once files are loaded, the lobby shows a live summary of everything that has been uploaded and is ready to share.

<p align="center">
  <img src="assets/screenshots/06-lobby-files-list.png" width="700" alt="Uploaded files list">
</p>

---

### 3 - Session Start: Shared Window & Remote Controls

When all participants are ready and the meeting starts, two windows open automatically: the **Shared Window** (visible and synced to all participants) and the **Remote Controls** panel (local to each participant, used to push content to the shared window).

| Shared Window | Remote Controls |
|:---:|:---:|
| ![Shared window](assets/screenshots/07-shared-window.png) | ![Remote controls](assets/screenshots/08-remote-controls.png) |

---

### 4 - Shared Window: Medical Documents

Any participant can push a PDF document (medical history, vitals, blood tests) to the shared window. Scroll position is synchronized in real time.

<p align="center">
  <img src="assets/screenshots/09-shared-window-pdf.png" width="700" alt="Shared window with PDF">
</p>

---

### 5 - Shared Window: CT Scan

A participant pushes a CT scan to the shared window. Slice navigation and window/level preset are synchronized across all devices.

<p align="center">
  <img src="assets/screenshots/10-shared-window-ct.png" width="700" alt="Shared window with CT scan">
</p>

---

### 6 - Annotation: Local Canvas

While the CT scan is on the shared window, any participant can open a local 2D annotation canvas tied to the current slice. The canvas is independent and private until explicitly shared.

<p align="center">
  <img src="assets/screenshots/11-ct-and-annotation-open.png" width="700" alt="CT and annotation open locally">
</p>

---

### 7 - Annotation: Drawing

The participant draws on the annotation canvas using a spatial stylus. Strokes are captured locally at native latency.

<p align="center">
  <img src="assets/screenshots/12-annotation-drawing.png" width="700" alt="Drawing on the annotation canvas">
</p>

---

### 8 - Annotation: Shared on the Meeting

Once the annotation is ready, the participant pushes it to the shared window. All participants see the annotated slice in sync.

<p align="center">
  <img src="assets/screenshots/13-annotation-shared.png" width="700" alt="Annotation shared on the meeting">
</p>

---

### 9 - Full Session View

An example of a complete session: a participant has medical documents open locally, the CT scan is on the shared window, and an annotation canvas is open alongside.

<p align="center">
  <img src="assets/screenshots/14-full-session.png" width="900" alt="Full session view">
</p>

---

### Navigation map

```
HomeView  (not in session)
  ├── "DICOM Viewer"     →  Offline DICOM visualizer
  ├── "Start meeting"    →  LobbyView (file upload + start SharePlay)
  └── "Annotations"      →  SavedAnnotationsView

LobbyView  (pre-session)
  ├── Load .atria Package button
  ├── 7 manual upload buttons (one per exam/document category)
  └── "Start meeting"    →  GroupActivitySharingSheet → session

Session
  ├── SharedWindow       →  CT / Echo / Coro / PDF (synced to all)
  ├── RemoteControls     →  Push content to SharedWindow (local)
  └── Annotation canvas  →  Draw locally → push to SharedWindow
```

`RootView` drives the top-level switch. Once `sessionHasStarted` latches to `true` it never reverts — late joiners skip the lobby and land directly in `SharedWindow`.

---

## Getting Started

### Prerequisites

- Xcode 26 or later
- Apple Vision Pro (for SharePlay and immersive drawing features)
- visionOS 26 Simulator (for basic UI testing without SharePlay)

### Clone and open

```bash
git clone <repo-url>
cd ATRIA
open ATRIA.xcodeproj
```

Select the **ATRIA** scheme for visionOS or **ATRIAmac** for the macOS companion, then build and run.

---

## Testing

### visionOS app tests

```bash
xcodebuild test \
  -project ATRIA.xcodeproj \
  -scheme ATRIA \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
```

### macOS companion tests

```bash
xcodebuild test \
  -project ATRIA.xcodeproj \
  -scheme ATRIAmac \
  -destination 'platform=macOS'
```

### DICOM decoder package tests (no Xcode required)

```bash
cd Packages/DICOM-Decoder
swift test

# Run a single test
swift test --filter DCMDecoderTests/testSomething
```

### What is tested

Tests use Apple's **Swift Testing** framework (`@Suite`, `@Test` macros) — not XCTest.

| Test suite | What it covers |
|---|---|
| `ViewerStoreTests` | DICOM loading, preset selection, exam navigation |
| `SessionStoreTests` | SharePlay message routing and state transitions |
| `AnnotationStoreTests` | Session lifecycle and stroke management |
| `DocumentStoreTests` | File URL management and shared window state |
| `DrawingStoreTests` | Brush settings, stroke history, undo/redo |
| `FolderStoreTests` (macOS) | Folder creation and iCloud upload lifecycle |

Stores are constructed directly with `MockDICOMImporter` and an inactive `SharePlayCoordinator()` (send calls are no-ops when there is no live `GroupSession`). Views are not unit-tested.

---

## macOS Companion App

<img src="assets/product%20page/macOS/ATRIAmac%20Product%20Page%201.png" width="600" alt="ATRIA Companion App screenshot"/>

The **ATRIAmac** target is a standalone drag-and-drop organizer with no SharePlay dependency. It follows the same MV + store pattern.

**Workflow:**
1. Drag files into one of seven category tiles (Medical History, Vitals, Blood Tests, Echo, CT, Coro, Other).
2. Name the folder in the side panel.
3. Click **Create Folder**. This will open a panel to choose a save location. 
4. **Upload to iCloud** Save the folder to iCloud Drive as a `.atria` package.
5. Load the `.atria` package in the visionOS app.

The output is a single `.atria` package that the visionOS app can open directly. All of the files will be stored inside the package.

---

## Debug Flags

`ATRIA/App/DebugFlags.swift` exposes compile-time flags for development:

| Flag | Effect |
|---|---|
| `bypassSharePlay` | Simulates a live SharePlay session without requiring FaceTime. Useful for UI testing on a single device or in the simulator. Set the debug flag to `true` to enable it. |

To enable it, open `ATRIA/App/DebugFlags.swift` and set the flag to `true`:

```swift
// DebugFlags.swift
// Toggle `bypassSharePlay` to simulate a live session without FaceTime.

enum DebugFlags {
    static let bypassSharePlay = true  // ← change this
}
```

> **Important:** always set this back to `false` before committing. Never merge a PR with `bypassSharePlay = true`.

---

## Contributing

We welcome contributions from collaborators and researchers. Please follow the guidelines below to keep the codebase clean and the review process efficient.

### Branch strategy

```
main        ← stable, production-ready code
  └── develop       ← integration branch, all PRs merge here first
        └── feature/your-feature-name   ← your work
        └── fix/short-description-of-bug
        └── docs/what-you-documented
```

- **Never push directly to `main` or `develop`.**
- Always branch off `develop` and open your PR back into `develop`.
- Use lowercase and hyphens: `feature/annotation-export`, `fix/slice-sync-crash`.

### Opening a Pull Request

**1. Keep it focused**  
One PR = one feature or one fix. If you find yourself writing "and also…" in the description, split it into two PRs.

**2. Write a clear title**  
Use the format: `[Type] Short description` — e.g.:

| Type | When to use |
|---|---|
| `[Feature]` | New capability added |
| `[Fix]` | Bug corrected |
| `[Refactor]` | Code restructured with no behavior change |
| `[Docs]` | Documentation only |
| `[Test]` | Tests added or updated |

**3. Fill in the PR description**  
Every PR must answer these three questions:

- **What does this PR do?** — one paragraph describing the change and why it is needed.
- **How was it tested?** — describe how you verified the change. If it requires a real device, say so.
- **Are there any known limitations or follow-ups?** — list anything deliberately left out of scope.

**4. Use the checklist**  
Before marking the PR as ready for review, confirm:

- [ ] Branch is up to date with `develop` (`git pull --rebase origin develop`)
- [ ] The app builds without warnings on both `ATRIA` (visionOS) and `ATRIAmac` (macOS) schemes
- [ ] All existing tests pass (`xcodebuild test` — see Testing section)
- [ ] New store logic has unit tests in `ATRIATests/`
- [ ] No pixel data, credentials, or patient data are included in any commit
- [ ] If a new SharePlay message type was added, `DICOMSyncMessage.Kind`, `SessionStore.applyMessage(_:)`, and `SharePlayCoordinator.apply(_:from:)` are all updated consistently
- [ ] Screenshots or a short screen recording are attached if the change affects any UI

**5. Request a review**  
Assign at least one reviewer before marking the PR ready. Do not merge your own PR.

### Commit messages

Write short, imperative commit messages that describe *what* changed:

```
Add annotation export to PDF
Fix slice index out-of-bounds on empty exam
Update SharePlay coordinator to handle new preset message
```

Avoid vague messages like `fix stuff`, `WIP`, or `changes`.

### What not to include in a PR

- Unrelated refactors or formatting changes mixed with functional changes
- Commented-out code left as a fallback
- Debug flags left set to `true`
- New files not referenced by anything in the project

---

## License

_To be added._

---

## Acknowledgements

Built with SwiftUI, RealityKit, GroupActivities, PencilKit, SwiftData, and PDFKit.

---

## Disclaimer

ATRIA is a research prototype and is **not approved for medical use**. It does not provide medical advice, diagnosis, treatment suggestions, or any form of clinical assistance. Do not rely on this tool for any medical decision-making. For questions or feedback, visit [atria-team.github.io](https://atria-team.github.io/).
