// DebugFlags.swift
// Toggle `bypassSharePlay` to simulate a live session without FaceTime.
// To revert: set to false, or delete this file and remove the 3 references
// in RootView.swift and SharePlayCoordinator.swift.

enum DebugFlags {
    static let bypassSharePlay = true
}
