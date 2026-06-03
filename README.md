![ATRIA Banner](assets/GitHub%20banner%20ATRIA.png)

# ATRIA Heart Team Meetings for Apple Vision Pro

> A spatial, multi-participant visionOS meeting tool developed to help the Heart Team define the best strategical decision and approach to a cardiac surgery.

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

### 1 — Home

The entry point of the app. From here the user can open the offline DICOM visualizer, browse saved annotations, or start a new meeting.

| Home | Offline DICOM Viewer | Annotations |
|:---:|:---:|:---:|
| ![Home view](assets/screenshots/01-home.png) | ![Offline DICOM visualizer](assets/screenshots/02-dicom-viewer.png) | ![Saved annotations](assets/screenshots/03-annotations.png) |

---

### 2 — Lobby: Loading Patient Files

Before starting a meeting, the host uploads the patient's files. This can be done in two ways: loading a pre-packaged `.atria` file from iCloud, or uploading each category of files manually.

| Load .atria Package | Upload Files Manually |
|:---:|:---:|
| ![Load .atria package](assets/screenshots/04-lobby-atria-package.png) | ![Manual file upload](assets/screenshots/05-lobby-manual-upload.png) |

Once files are loaded, the lobby shows a live summary of everything that has been uploaded and is ready to share.

| Uploaded Files List |
|:---:|
| ![Uploaded files list](assets/screenshots/06-lobby-files-list.png) |

---

### 3 — Session Start: Shared Window & Remote Controls

When all participants are ready and the meeting starts, two windows open automatically: the **Shared Window** (visible and synced to all participants) and the **Remote Controls** panel (local to each participant, used to push content to the shared window).

| Shared Window | Remote Controls |
|:---:|:---:|
| ![Shared window](assets/screenshots/07-shared-window.png) | ![Remote controls](assets/screenshots/08-remote-controls.png) |

---

### 4 — Shared Window: Medical Documents

Any participant can push a PDF document (medical history, vitals, blood tests) to the shared window. Scroll position is synchronized in real time.

| Shared Window — PDF |
|:---:|
| ![Shared window with PDF](assets/screenshots/09-shared-window-pdf.png) |

---

### 5 — Shared Window: CT Scan

A participant pushes a CT scan to the shared window. Slice navigation and window/level preset are synchronized across all devices.

| Shared Window — CT Scan |
|:---:|
| ![Shared window with CT scan](assets/screenshots/10-shared-window-ct.png) |

---

### 6 — Annotation: Local Canvas

While the CT scan is on the shared window, any participant can open a local 2D annotation canvas tied to the current slice. The canvas is independent and private until explicitly shared.

| CT on Shared Window + Annotation Open Locally |
|:---:|
| ![CT and annotation open](assets/screenshots/11-ct-and-annotation-open.png) |

---

### 7 — Annotation: Drawing

The participant draws on the annotation canvas using a spatial stylus. Strokes are captured locally at native latency.

| Drawing on the Annotation Canvas |
|:---:|
| ![Drawing on annotation](assets/screenshots/12-annotation-drawing.png) |

---

### 8 — Annotation: Shared on the Meeting

Once the annotation is ready, the participant pushes it to the shared window. All participants see the annotated slice in sync.

| Annotation Shared on the Meeting |
|:---:|
| ![Annotation shared](assets/screenshots/13-annotation-shared.png) |

---

### 9 — Full Session View

An example of a complete session: a participant has medical documents open locally, the CT scan is on the shared window, and an annotation canvas is open alongside.

| Medical Data Locally · CT on Shared Window · Annotation Open |
|:---:|
| ![Full session view](assets/screenshots/14-full-session.png) |

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

---

## License

_To be added._

---

## Acknowledgements

Built with SwiftUI, RealityKit, GroupActivities, PencilKit, SwiftData, and PDFKit.
