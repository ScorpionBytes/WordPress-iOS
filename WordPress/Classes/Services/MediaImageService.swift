import UIKit
import CoreData

/// A service for retrieval and caching of thumbnails for Media objects.
final class MediaImageService: NSObject {
    static let shared = MediaImageService()

    private let session: URLSession
    private let coreDataStack: CoreDataStackSwift
    private let mediaFileManager: MediaFileManager
    private let ioQueue = DispatchQueue(label: "org.automattic.MediaImageService")

    init(coreDataStack: CoreDataStackSwift = ContextManager.shared,
         mediaFileManager: MediaFileManager = MediaFileManager(directory: .cache)) {
        self.coreDataStack = coreDataStack
        self.mediaFileManager = mediaFileManager

        let configuration = URLSessionConfiguration.default
        // `MediaImageService` has its own disk cache, so it's important to
        // disable the native url cache which is by default set to `URLCache.shared`
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
    }

    static func migrateCacheIfNeeded() {
        let didMigrateKey = "MediaImageService-didMigrateCacheKey"
        guard !UserDefaults.standard.bool(forKey: didMigrateKey) else {
            return
        }
        UserDefaults.standard.set(true, forKey: didMigrateKey)
        DispatchQueue.global(qos: .utility).async {
            MediaFileManager.clearAllMediaCacheFiles(onCompletion: nil, onError: nil)
        }
    }

    // MARK: - Thumbnails

    /// Returns a thumbnail for the given media asset. The images are decompressed
    /// (or bitmapped) and are ready to be displayed.
    @MainActor
    func thumbnail(for media: Media, size: ThumbnailSize = .small) async throws -> UIImage {
        guard media.remoteStatus != .stub else {
            let media = try await fetchStubMedia(for: media)
            return try await _thumbnail(for: media, size: size)
        }
        return try await _thumbnail(for: media, size: size)
    }

    @MainActor
    private func _thumbnail(for media: Media, size: ThumbnailSize) async throws -> UIImage {
        if let image = await cachedThumbnail(for: media.objectID, size: size) {
            return image
        }
        if let image = await localThumbnail(for: media, size: size) {
            return image
        }
        return try await remoteThumbnail(for: media, size: size)
    }

    // MARK: - Cached Thumbnail

    /// Returns a local thumbnail for the given media object (if available).
    private func cachedThumbnail(for mediaID: NSManagedObjectID, size: ThumbnailSize) async -> UIImage? {
        return try? await Task.detached {
            let imageURL = try self.getCachedThumbnailURL(for: mediaID, size: size)
            let data = try Data(contentsOf: imageURL)
            return try makeImage(from: data)
        }.value
    }

    // The save is performed asynchronously to eliminate any delays. It's
    // exceedingly unlikely it will result in any duplicated work thanks to the
    // memore caches.
    private func saveThumbnail(for mediaID: NSManagedObjectID, size: ThumbnailSize, _ closure: @escaping (URL) throws -> Void) {
        ioQueue.async {
            if let targetURL = try? self.getCachedThumbnailURL(for: mediaID, size: size) {
                try? closure(targetURL)
            }
        }
    }

    private func getCachedThumbnailURL(for mediaID: NSManagedObjectID, size: ThumbnailSize) throws -> URL {
        let mediaID = mediaID.uriRepresentation().lastPathComponent
        return try mediaFileManager.makeLocalMediaURL(
            withFilename: "\(mediaID)-\(size.rawValue)-thumbnail",
            fileExtension: nil, // We don't know ahead of time
            incremented: false
        )
    }

    /// Flushes all pending I/O changes to disk.
    ///
    /// - warning: For testing purposes only.
    func flush() {
        ioQueue.sync {}
    }

    // MARK: - Local Thumbnail

    /// Generates a thumbnail from a local asset and saves it in cache.
    @MainActor
    private func localThumbnail(for media: Media, size: ThumbnailSize) async -> UIImage? {
        guard let sourceURL = media.absoluteLocalURL else {
            return nil
        }

        let exporter = makeThumbnailExporter(for: media, size: size)
        guard exporter.supportsThumbnailExport(forFile: sourceURL),
              let (_, export) = try? await exporter.exportThumbnail(forFileURL: sourceURL),
              let image = try? await makeImage(from: export.url)
        else {
            return nil
        }

        // The order is important to ensure `export.url` still exists when creating an image
        saveThumbnail(for: media.objectID, size: size) { targetURL in
            try FileManager.default.moveItem(at: export.url, to: targetURL)
        }

        return image
    }

    private func makeThumbnailExporter(for media: Media, size: ThumbnailSize) -> MediaThumbnailExporter {
        let exporter = MediaThumbnailExporter()
        exporter.mediaDirectoryType = .cache
        exporter.options.preferredSize = MediaImageService.getThumbnailSize(for: media, size: size)
        exporter.options.scale = 1 // In pixels
        return exporter
    }

    // MARK: - Remote Thumbnail

    /// Downloads a remote thumbnail and saves it in cache.
    @MainActor
    private func remoteThumbnail(for media: Media, size: ThumbnailSize) async throws -> UIImage {
        let targetSize = MediaImageService.getThumbnailSize(for: media, size: size)
        guard let imageURL = media.getRemoteThumbnailURL(targetSize: targetSize) else {
            // Self-hosted WordPress sites don't have `remoteThumbnailURL`, so
            // the app generates the thumbnail by itself.
            if media.mediaType == .video {
                return try await generateThumbnailForVideo(for: media, size: size)
            }
            throw URLError(.badURL)
        }

        let blogID = TaggedManagedObjectID(media.blog)
        let host = try await coreDataStack.performQuery { context in
            MediaHost(with: try context.existingObject(with: blogID))
        }
        let request = try await MediaRequestAuthenticator()
            .authenticatedRequest(for: imageURL, host: host)
        guard !Task.isCancelled else {
            throw CancellationError()
        }
        let (data, response) = try await session.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200..<400).contains(statusCode) else {
            throw URLError(.unknown)
        }
        let image = try await Task.detached {
            try makeImage(from: data)
        }.value
        saveThumbnail(for: media.objectID, size: size) { targetURL in
            try data.write(to: targetURL)
        }
        return image
    }

    // MARK: - Thubmnail for Video

    @MainActor
    private func generateThumbnailForVideo(for media: Media, size: ThumbnailSize) async throws -> UIImage {
        guard let videoURL = media.remoteURL.flatMap(URL.init) else {
            throw URLError(.badURL)
        }
        let exporter = makeThumbnailExporter(for: media, size: size)
        let (_, export) = try await exporter.exportThumbnail(forVideoURL: videoURL)
        let image = try await makeImage(from: export.url)

        // The order is important to ensure `export.url` exists when making an image
        saveThumbnail(for: media.objectID, size: size) { targetURL in
            try FileManager.default.moveItem(at: export.url, to: targetURL)
        }
        return image
    }

    // MARK: - Stubs

    @MainActor
    private func fetchStubMedia(for media: Media) async throws -> Media {
        guard let mediaID = media.mediaID else {
            throw MediaThumbnailExporter.ThumbnailExportError.failedToGenerateThumbnailFileURL
        }
        let mediaRepository = MediaRepository(coreDataStack: coreDataStack)
        let objectID = try await mediaRepository.getMedia(withID: mediaID, in: .init(media.blog))
        return try coreDataStack.mainContext.existingObject(with: objectID)
    }
}

// MARK: - MediaImageService (ThumbnailSize)

extension MediaImageService {

    enum ThumbnailSize: String {
        /// The small thumbnail that can be used in collection view cells and
        /// similar situations.
        case small

        /// A medium thumbnail thumbnail that can typically be used to fit
        /// the entire screen on iPhone or a large portion of the sreen on iPad.
        case medium
    }

    /// Returns an optimal target size in pixels for a thumbnail of the given
    /// size for the given media asset.
    static func getThumbnailSize(for media: Media, size: ThumbnailSize) -> CGSize {
        let mediaSize = CGSize(
            width: CGFloat(media.width?.floatValue ?? 0),
            height: CGFloat(media.height?.floatValue ?? 0)
        )
        let targetSize = MediaImageService.getPreferredThumbnailSize(for: size)
        return MediaImageService.targetSize(forMediaSize: mediaSize, targetSize: targetSize)
    }

    /// Returns a preferred thumbnail size (in pixels) optimized for the device.
    ///
    /// - important: It makes sure the app uses the same thumbnails across
    /// different screens and presentation modes to avoid fetching and caching
    /// more than one version of the same image.
    private static func getPreferredThumbnailSize(for thumbnail: ThumbnailSize) -> CGSize {
        let minScreenSide = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        switch thumbnail {
        case .small:
            /// The size is calculated to fill a collection view cell, assuming the app
            /// displays a 4 or 5 cells in one row. The cell size can vary depending
            /// on whether the device is in landscape or portrait mode, but the thumbnail size is
            /// guaranteed to always be the same across app launches and optimized for
            /// a portraint (dominant) mode.
            let itemPerRow = UIDevice.current.userInterfaceIdiom == .pad ? 5 : 4
            let availableWidth = minScreenSide - SiteMediaCollectionViewController.spacing * CGFloat(itemPerRow - 1)
            let targetSide = (availableWidth / CGFloat(itemPerRow)).rounded(.down)
            let targetSize = CGSize(width: targetSide, height: targetSide)
            return targetSize.scaled(by: UIScreen.main.scale)
        case .medium:
            let side = min(1024, minScreenSide * UIScreen.main.scale)
            return CGSize(width: side, height: side)
        }
    }

    /// Image CDN (Photon) and `MediaImageExporter` both don't support "aspect-fill"
    /// resizing mode, so the service performs the necessary calculations by itself.
    ///
    /// Example: if media size is 2000x3000 px and targetSize is 200x200 px, the
    /// returned value will be 200x300 px. For more examples, see `MediaImageServiceTests`.
    static func targetSize(forMediaSize mediaSize: CGSize, targetSize originalTargetSize: CGSize) -> CGSize {
        guard mediaSize.width > 0 && mediaSize.height > 0 else {
            return originalTargetSize
        }
        // Scale image to fill the target size but avoid upscaling
        let scale = min(1, max(
            originalTargetSize.width / mediaSize.width,
            originalTargetSize.height / mediaSize.height
        ))
        let targetSize = mediaSize.scaled(by: scale).rounded()

        // Sanitize the size to make sure ultra-wide panoramas are still resized
        // to fit the target size, but increase it a bit for an acceptable size.
        let threshold: CGFloat = 4
        if targetSize.width > originalTargetSize.width * threshold || targetSize.height > originalTargetSize.height * threshold {
            return CGSize(
                width: min(targetSize.width, originalTargetSize.width * threshold),
                height: min(targetSize.height, originalTargetSize.height * threshold)
            )
        }
        return targetSize
    }
}

// MARK: - Helpers (RemoteURL)

private extension Media {
    /// Returns the thumbnail remote URL with a given target size. It uses
    /// Image CDN (formerly Photon) if available.
    ///
    /// - parameter targetSize: Target size in pixels.
    func getRemoteThumbnailURL(targetSize: CGSize) -> URL? {
        switch mediaType {
        case .image:
            guard let remoteURL = remoteURL.flatMap(URL.init) else {
                return nil
            }
            // Download a non-retina version for GIFs: makes a massive difference
            // in terms of size. Example: 2.4 MB -> 350 KB.
            let scale = UIScreen.main.scale
            var targetSize = targetSize
            if remoteURL.isGif {
                targetSize = targetSize
                    .scaled(by: 1.0 / scale)
                    .scaled(by: min(2, scale))
            }
            if !isEligibleForPhoton {
                return WPImageURLHelper.imageURLWithSize(targetSize, forImageURL: remoteURL)
            } else {
                let targetSize = targetSize.scaled(by: 1.0 / UIScreen.main.scale)
                return PhotonImageURLHelper.photonURL(with: targetSize, forImageURL: remoteURL)
            }
        default:
            return remoteThumbnailURL.flatMap(URL.init)
        }
    }

    var isEligibleForPhoton: Bool {
        !(blog.isPrivateAtWPCom() || (!blog.isHostedAtWPcom && blog.isBasicAuthCredentialStored()))
    }
}

// MARK: - Helpers (Decompression)

private func makeImage(from fileURL: URL) async throws -> UIImage {
    try await Task.detached {
        let data = try Data(contentsOf: fileURL)
        return try makeImage(from: data)
    }.value
}

// Forces decompression (or bitmapping) to happen in the background.
// It's very expensive for some image formats, such as JPEG.
private func makeImage(from data: Data) throws -> UIImage {
    guard let image = UIImage(data: data) else {
        throw URLError(.cannotDecodeContentData)
    }
    if data.isMatchingMagicNumbers(Data.gifMagicNumbers) {
        return AnimatedImageWrapper(gifData: data) ?? image
    }
    guard isDecompressionNeeded(for: data) else {
        return image
    }
    return image.preparingForDisplay() ?? image
}

private func isDecompressionNeeded(for data: Data) -> Bool {
    // This check is required to avoid the following error messages when
    // using `preparingForDisplay`:
    //
    //    [Decompressor] Error -17102 decompressing image -- possibly corrupt
    //
    // More info: https://github.com/SDWebImage/SDWebImage/issues/3365
    data.isMatchingMagicNumbers(Data.jpegMagicNumbers)
}

private extension Data {
    // JPEG magic numbers https://en.wikipedia.org/wiki/JPEG
    static let jpegMagicNumbers: [UInt8] = [0xFF, 0xD8, 0xFF]

    // GIF magic numbers https://en.wikipedia.org/wiki/GIF
    static let gifMagicNumbers: [UInt8] = [0x47, 0x49, 0x46]

    func isMatchingMagicNumbers(_ numbers: [UInt8?]) -> Bool {
        guard self.count >= numbers.count else {
            return false
        }
        return zip(numbers.indices, numbers).allSatisfy { index, number in
            guard let number = number else { return true }
            return self[index] == number
        }
    }
}
