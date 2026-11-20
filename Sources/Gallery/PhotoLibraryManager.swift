import Foundation
import Photos
import SwiftUI
import UIKit

struct PhotoEXIFMetadata: Codable, Equatable {
    var filterName: String
    var iso: Int
    var shutterSpeed: String
    var capturedAt: Date
    var flashFired: Bool
    var isRawDNG: Bool = false
    var lensModel: String
    var seed: UInt64
    var appliedParameters: FilterParameters
}

struct CapturedPhotoItem: Identifiable, Codable, Equatable {
    let id: UUID
    let processedFilename: String
    let originalFilename: String
    let thumbnailFilename: String
    var rawDNGFilename: String?
    var metadata: PhotoEXIFMetadata
}

@MainActor
final class PhotoLibraryManager: ObservableObject {
    @Published var items: [CapturedPhotoItem] = []
    @Published var latestThumbnail: UIImage?

    private let fileManager = FileManager.default
    private let indexFilename = "digicam_manifest.json"

    private var baseDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("DigicamRolls", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    init() {
        loadManifest()
    }

    func saveCapture(
        originalJPEG: Data,
        processedJPEG: Data,
        thumbnailJPEG: Data,
        rawDNGData: Data? = nil,
        metadata: PhotoEXIFMetadata
    ) {
        let id = UUID()
        let procName = "\(id.uuidString)_proc.jpg"
        let origName = "\(id.uuidString)_orig.jpg"
        let thumbName = "\(id.uuidString)_thumb.jpg"
        let dngName: String? = rawDNGData != nil ? "\(id.uuidString)_raw.dng" : nil

        do {
            try processedJPEG.write(to: baseDirectory.appendingPathComponent(procName), options: .atomic)
            try originalJPEG.write(to: baseDirectory.appendingPathComponent(origName), options: .atomic)
            try thumbnailJPEG.write(to: baseDirectory.appendingPathComponent(thumbName), options: .atomic)
            if let rawDNGData, let dngName {
                try rawDNGData.write(to: baseDirectory.appendingPathComponent(dngName), options: .atomic)
            }

            let item = CapturedPhotoItem(
                id: id,
                processedFilename: procName,
                originalFilename: origName,
                thumbnailFilename: thumbName,
                rawDNGFilename: dngName,
                metadata: metadata
            )
            items.insert(item, at: 0)
            persistManifest()
            latestThumbnail = UIImage(data: thumbnailJPEG)

            exportToSystemPhotos(jpegData: processedJPEG, dngData: rawDNGData)
        } catch {}
    }

    func updateReEditedPhoto(
        itemID: UUID,
        newParameters: FilterParameters,
        newFilterName: String
    ) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items[index]
        let origURL = baseDirectory.appendingPathComponent(item.originalFilename)
        guard let originalData = try? Data(contentsOf: origURL) else { return }

        let seed = item.metadata.seed
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let rendered = ImageProcessor.shared.renderFullResolution(
                from: originalData,
                parameters: newParameters,
                seed: seed
            ) else { return }

            Task { @MainActor in
                guard let self, let idx = self.items.firstIndex(where: { $0.id == itemID }) else { return }
                let procURL = self.baseDirectory.appendingPathComponent(self.items[idx].processedFilename)
                let thumbURL = self.baseDirectory.appendingPathComponent(self.items[idx].thumbnailFilename)
                try? rendered.processedJPEG.write(to: procURL, options: .atomic)
                try? rendered.thumbnailJPEG.write(to: thumbURL, options: .atomic)

                self.items[idx].metadata.appliedParameters = newParameters
                self.items[idx].metadata.filterName = newFilterName
                self.persistManifest()

                if idx == 0 {
                    self.latestThumbnail = UIImage(data: rendered.thumbnailJPEG)
                }
            }
        }
    }

    func deletePhoto(_ item: CapturedPhotoItem) {
        items.removeAll { $0.id == item.id }
        try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(item.processedFilename))
        try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(item.originalFilename))
        try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(item.thumbnailFilename))
        if let dng = item.rawDNGFilename {
            try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(dng))
        }
        persistManifest()
        refreshLatestThumbnail()
    }

    func loadProcessedImage(for item: CapturedPhotoItem) -> UIImage? {
        let url = baseDirectory.appendingPathComponent(item.processedFilename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadOriginalData(for item: CapturedPhotoItem) -> Data? {
        try? Data(contentsOf: baseDirectory.appendingPathComponent(item.originalFilename))
    }

    func loadThumbnail(for item: CapturedPhotoItem) -> UIImage? {
        let url = baseDirectory.appendingPathComponent(item.thumbnailFilename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func exportItemToPhotos(_ item: CapturedPhotoItem, completion: @escaping (Bool) -> Void) {
        let url = baseDirectory.appendingPathComponent(item.processedFilename)
        guard let data = try? Data(contentsOf: url) else {
            completion(false)
            return
        }
        let dngData = item.rawDNGFilename.flatMap { try? Data(contentsOf: baseDirectory.appendingPathComponent($0)) }
        exportToSystemPhotos(jpegData: data, dngData: dngData, completion: completion)
    }

    private func exportToSystemPhotos(jpegData: Data, dngData: Data? = nil, completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: jpegData, options: nil)
                if let dngData {
                    let options = PHAssetResourceCreationOptions()
                    options.uniformTypeIdentifier = "com.adobe.raw-image"
                    request.addResource(with: .alternatePhoto, data: dngData, options: options)
                }
            }) { success, _ in
                DispatchQueue.main.async { completion?(success) }
            }
        }
    }

    private func loadManifest() {
        let url = baseDirectory.appendingPathComponent(indexFilename)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CapturedPhotoItem].self, from: data) else {
            return
        }
        items = decoded
        refreshLatestThumbnail()
    }

    private func persistManifest() {
        let url = baseDirectory.appendingPathComponent(indexFilename)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func refreshLatestThumbnail() {
        if let first = items.first {
            latestThumbnail = loadThumbnail(for: first)
        } else {
            latestThumbnail = nil
        }
    }
}
