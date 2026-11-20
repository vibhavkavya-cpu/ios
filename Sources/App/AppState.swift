import Foundation
import SwiftUI

enum CameraMode: String, CaseIterable, Identifiable {
    case raw = "RAW"
    case manual = "MANUAL"
    case photo = "PHOTO"
    case square = "SQUARE"

    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    @Published var activeMode: CameraMode = .photo
    @Published var isFilterDrawerOpen: Bool = false
    @Published var isGalleryPresented: Bool = false
    @Published var isEditorPresented: Bool = false
    @Published var editingPhotoItem: CapturedPhotoItem?

    let cameraManager = CameraManager()
    let filterLibrary = FilterLibrary()
    let libraryManager = PhotoLibraryManager()

    init() {
        cameraManager.bindFilterLibrary(filterLibrary)
        cameraManager.bindLibraryManager(libraryManager)
    }
}
