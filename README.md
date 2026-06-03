# ATRIA — Collaborative Clinical Viewer for Apple Vision Pro

> A spatial, multi-participant DICOM viewer built for visionOS with real-time SharePlay synchronization, 3D immersive drawing, and 2D annotation.

---

## Overview

ATRIA enables medical teams to review diagnostic imaging studies together in mixed reality. Multiple clinicians wearing Apple Vision Pro can join a shared session and simultaneously explore CT scans, echocardiograms, and coronary angiographies — with slice navigation, window/level adjustments, and annotations synchronized in real time across all participants.

A companion macOS app allows users to organize patient files into structured `.atria` packages that can be loaded directly into a session.

**Key capabilities:**
- Real-time DICOM slice viewing synchronized across participants via SharePlay
- 3D spatial drawing with RealityKit in a mixed-reality immersive space
- 2D annotation with Apple Pencil Pro (normalized strokes synced to peers)
- Support for CT, Echo, and Coronary Angiography exam types
- Offline document sharing (PDFs, images) alongside imaging studies
- `.atria` package format for bundling a full patient exam for transport
- macOS companion app for organizing and uploading patient files to iCloud

---

## Platform Requirements

| Target | Platform | Minimum OS |
|---|---|---|
| `ATRIA` (visionOS) | Apple Vision Pro | visionOS 26.0 |
| `ATRIAmac` (macOS) | Mac | macOS 26.2 |

**SharePlay features require a real visionOS device** — they cannot be fully tested in the simulator.

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

The app follows an **MV (Model-View)** pattern — there are no ViewModels. `@Observable` stores replace that layer. Views read state directly from injected stores and call action methods on them.

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

ATRIA uses Apple's **GroupActivities** framework to synchronize state across participants. **No pixel data or file contents cross the wire** — only control signals. Each participant loads their own local copy of exam files.

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

**Adding a new synced state:** add a `case` to `DICOMSyncMessage.Kind`, handle it in `SessionStore.applyMessage(_:)`, and add it to the guard list in `SharePlayCoordinator.apply(_:from:)` so `isApplyingRemoteChange` is raised correctly.

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

## Navigation Flow

```
HomeView3  (not in session)
  ├── "DICOM Viewer"     →  ContentView
  ├── "Start meeting"    →  LobbyView2 (file upload + start SharePlay)
  └── "Annotations"      →  SavedAnnotationsView

LobbyView2  (pre-lobby, before SharePlay)
  ├── Load .atria Package button
  ├── 7 manual upload buttons (one per exam/document category)
  └── "Start meeting"    →  GroupActivitySharingSheet

LobbyView  (in-session, waiting for all participants)
  └── All ready          →  sessionHasStarted latches → SharedWindow
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
1. Drag files into one of seven category tiles (Medical History, Vitals, Blood Tests, Echo, CT, Coro, Other)
2. Name the folder in the side panel
3. Click **Create Folder** — opens `NSOpenPanel` to choose a save location
4. **Upload to iCloud** — moves the folder to iCloud Drive as a `.atria` package
5. Load the `.atria` package in the visionOS app via **LobbyView2**

The output is a single `.atria` package (custom UTI `com.atria-team.atria-package`) that the visionOS app can open directly.

---

## Debug Flags

`ATRIA/App/DebugFlags.swift` exposes compile-time flags for development:

| Flag | Effect |
|---|---|
| `bypassSharePlay` | Simulates a live SharePlay session without requiring FaceTime — useful for UI testing on a single device |

---

## License

_To be added._

---

## Citation

If you use ATRIA in your research, please cite:

```
@software{atria2025,
  title   = {ATRIA: A Collaborative Spatial DICOM Viewer for Apple Vision Pro},
  year    = {2025},
  url     = {<repo-url>}
}
```

---

## Acknowledgements

Built with SwiftUI, RealityKit, GroupActivities, PencilKit, SwiftData, and PDFKit.
