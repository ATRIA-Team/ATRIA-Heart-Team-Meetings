//
//  ImmersiveDrawingView.swift
//  DemoDICOM
//
//  Adapted from SharedSpaceExample2 by Igor Tarantino.
//

import SwiftUI
import RealityKit
import ARKit

/// Mixed-immersion RealityKit space that:
/// - Tracks the spatial stylus via `StylusTipManager`
/// - Draws 3D tube strokes when the primary button is held
/// - Broadcasts each stroke point to SharePlay peers in real time
/// - Receives peer stroke points and clears via `NotificationCenter`
struct ImmersiveDrawingView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var drawingRoot  = Entity()
    @State private var stylusManager = StylusTipManager()

    @State private var activeStrokes: [UUID: StrokeEntity] = [:]
    @State private var removedStrokes: [(id: UUID, entity: StrokeEntity)] = []
    @State private var currentLocalStrokeID: UUID?
    @State private var lastTipPosition: SIMD3<Float>?

    // MARK: - Body

    var body: some View {
        RealityView { content in
            // Drawing strokes live here
            content.add(drawingRoot)

            // Stylus anchors need a root entity in the RealityKit scene
            let stylusRoot = Entity()
            content.add(stylusRoot)
            stylusManager.rootEntity = stylusRoot
            await stylusManager.handleControllerSetup()

            // Rebuild any strokes that survived a previous stop/start drawing cycle
            for (id, record) in store.drawing.activeStrokeData {
                let entity = buildStrokeEntity(from: record)
                drawingRoot.addChild(entity)
                activeStrokes[id] = entity
            }
            // Rebuild removed strokes so redo still works after reopening the space
            for (id, record) in store.drawing.removedStrokeData {
                let entity = buildStrokeEntity(from: record)
                removedStrokes.append((id: id, entity: entity))
            }
        }
        // Open the floating brush-controls window when the immersive space starts,
        // unless the caller already provides its own brush controls.
        .onAppear {
            if !store.suppressDrawingToolsPanel && !store.session.isInSession {
                openWindow(id: "drawingTools")
            }
            store.suppressDrawingToolsPanel = false
        }
        // Close it when the immersive space ends (e.g. dismissed from elsewhere)
        .onDisappear {
            dismissWindow(id: "drawingTools")
        }
        // Receive remote draw points from peers
        .onReceive(
            NotificationCenter.default.publisher(for: .remoteDrawPoint)
        ) { notification in
            guard let message = notification.object as? DrawPointMessage else { return }
            let color = UIColor(
                red:   CGFloat(message.color.x),
                green: CGFloat(message.color.y),
                blue:  CGFloat(message.color.z),
                alpha: CGFloat(message.color.w)
            )
            addPoint(
                strokeID:  message.strokeID,
                point:     message.point,
                thickness: message.thickness,
                color:     color,
                isLocal:   false
            )
        }
        // Receive clear-drawings command (local or remote)
        .onReceive(
            NotificationCenter.default.publisher(for: .clearAllDrawings)
        ) { _ in
            drawingRoot.children.removeAll()
            activeStrokes.removeAll()
            removedStrokes.removeAll()
        }
        // Undo last local stroke
        .onReceive(
            NotificationCenter.default.publisher(for: .undoLastDrawingStroke)
        ) { notification in
            guard let id = notification.object as? UUID,
                  let entity = activeStrokes[id] else { return }
            entity.removeFromParent()
            activeStrokes[id] = nil
            removedStrokes.append((id: id, entity: entity))
        }
        // Redo last undone local stroke
        .onReceive(
            NotificationCenter.default.publisher(for: .redoLastDrawingStroke)
        ) { notification in
            guard let id = notification.object as? UUID,
                  let index = removedStrokes.firstIndex(where: { $0.id == id }) else { return }
            let entry = removedStrokes.remove(at: index)
            drawingRoot.addChild(entry.entity)
            activeStrokes[id] = entry.entity
        }
        // Main drawing loop — runs for the lifetime of this immersive space
        .task { await runDrawingLoop() }
    }

    // MARK: - Drawing loop

    /// Polls the stylus tip position every 10 ms and emits stroke points
    /// while the primary button is held. Points closer than 5 mm to the
    /// previous point are skipped to keep the mesh density reasonable.
    private func runDrawingLoop() async {
        let configuration = SpatialTrackingSession.Configuration(tracking: [.accessory])
        let session = SpatialTrackingSession()
        await session.run(configuration)

        while !Task.isCancelled {
            if stylusManager.isPrimaryButtonPressed == true,
               let currentPos = stylusManager.getTipPosition() {

                let strokeID = currentLocalStrokeID ?? UUID()
                currentLocalStrokeID = strokeID

                let farEnough: Bool
                if let last = lastTipPosition {
                    farEnough = simd_distance(currentPos, last) > 0.005
                } else {
                    farEnough = true
                }

                if farEnough {
                    let color = UIColor(store.drawing.brushColor)
                    addPoint(
                        strokeID:  strokeID,
                        point:     currentPos,
                        thickness: store.drawing.brushSize,
                        color:     color,
                        isLocal:   true
                    )
                    lastTipPosition = currentPos
                }
            } else {
                if let completedID = currentLocalStrokeID {
                    store.drawing.strokeCompleted(completedID)
                }
                currentLocalStrokeID = nil
                lastTipPosition = nil
            }

            try? await Task.sleep(nanoseconds: 10_000_000)   // ~10 ms
        }
    }

    // MARK: - Stroke management

    private func addPoint(
        strokeID: UUID,
        point: SIMD3<Float>,
        thickness: Float,
        color: UIColor,
        isLocal: Bool
    ) {
        // Create stroke entity on first point
        if activeStrokes[strokeID] == nil {
            let stroke = StrokeEntity(thickness: thickness, color: color)
            drawingRoot.addChild(stroke)
            activeStrokes[strokeID] = stroke
        }
        activeStrokes[strokeID]?.addPoint(point)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let colorVec = SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))

        // Persist point so strokes survive stop/start drawing
        store.drawing.recordPoint(strokeID: strokeID, point: point, thickness: thickness, color: colorVec)

        // Broadcast to peers only for locally drawn points
        if isLocal {
            store.session.sendDrawPoint(strokeID: strokeID, point: point, thickness: thickness, color: colorVec)
        }
    }

    private func buildStrokeEntity(from record: DrawingStore.StrokeRecord) -> StrokeEntity {
        let color = UIColor(
            red:   CGFloat(record.color.x),
            green: CGFloat(record.color.y),
            blue:  CGFloat(record.color.z),
            alpha: CGFloat(record.color.w)
        )
        let stroke = StrokeEntity(thickness: record.thickness, color: color)
        for pt in record.points { stroke.addPoint(pt) }
        return stroke
    }
}

// MARK: - DrawingToolsPanel

/// Floating brush-controls window opened automatically alongside the DrawingSpace.
/// Declared as a separate WindowGroup so visionOS makes it draggable.
struct DrawingToolsPanel: View {

    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var drawing = store.drawing
        VStack(spacing: 14) {
            HStack {
                Text("Drawing Tools")
                    .font(.headline)
                Spacer()
                Button {
                    store.isDrawingActive = false
                } label: {
                    Label("Stop Drawing", systemImage: "pencil.slash")
                }
            }

            Divider()

            HStack {
                Text("Color")
                Spacer()
                ColorPicker("Brush Color", selection: $drawing.brushColor, supportsOpacity: false)
                    .labelsHidden()
            }

            HStack {
                Text("Size")
                Slider(value: $drawing.brushSize, in: 0.001...0.02, step: 0.001)
                Text(String(format: "%.0f mm", store.drawing.brushSize * 1000))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

            Button(role: .destructive) {
                store.clearAllDrawings()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}
