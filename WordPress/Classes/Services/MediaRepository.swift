import Foundation

final class MediaRepository {

    enum Error: Swift.Error {
        case mediaNotFound
        case remoteAPIUnavailable
        case unknown
    }

    private let coreDataStack: CoreDataStackSwift
    private let remoteFactory: MediaServiceRemoteFactory

    init(coreDataStack: CoreDataStackSwift, remoteFactory: MediaServiceRemoteFactory = .init()) {
        self.coreDataStack = coreDataStack
        self.remoteFactory = remoteFactory
    }

    /// Get the Media object from the server using the blog and the mediaID as the identifier of the resource
    func getMedia(withID mediaID: NSNumber, in blogID: CoreDataObjectIdentifier<Blog>) async throws -> CoreDataObjectIdentifier<Media> {
        let remote = try await coreDataStack.performQuery { [remoteFactory] context in
            let blog = try context.existingObject(with: blogID)
            return remoteFactory.remote(for: blog)
        }
        guard let remote else {
            throw MediaRepository.Error.remoteAPIUnavailable
        }

        let remoteMedia: RemoteMedia? = try await withCheckedThrowingContinuation { continuation in
            remote.getMediaWithID(
                mediaID, success: continuation.resume(returning:),
                failure: { continuation.resume(throwing: $0 ?? MediaRepository.Error.unknown) })
        }
        guard let remoteMedia else {
            throw MediaRepository.Error.mediaNotFound
        }

        return try await coreDataStack.performAndSave { context in
            let blog = try context.existingObject(with: blogID)
            let media = Media.existingMediaWith(mediaID: mediaID, inBlog: blog) ?? Media.makeMedia(blog: blog)
            MediaHelper.update(media: media, with: remoteMedia)
            return try .ofUnsaved(media)
        }
    }

}

@objc class MediaServiceRemoteFactory: NSObject {

    @objc(remoteForBlog:)
    func remote(for blog: Blog) -> MediaServiceRemote? {
        if blog.supports(.wpComRESTAPI), let dotComID = blog.dotComID, let api = blog.wordPressComRestApi() {
            return MediaServiceRemoteREST(wordPressComRestApi: api, siteID: dotComID)
        }

        if let username = blog.username, let password = blog.password, let api = blog.xmlrpcApi {
            return MediaServiceRemoteXMLRPC(api: api, username: username, password: password)
        }

        return nil
    }
}
