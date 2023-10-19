import Foundation
import Combine

final class PostSearchViewModel: NSObject, NSFetchedResultsControllerDelegate {
    @Published var searchTerm = ""

    var objectDidChange: (() -> Void)?

    private let blog: Blog
    private let filters: PostListFilterSettings
    private let coreDataStack: CoreDataStack
    private let postRepository: PostRepository

    private var cancellables: [AnyCancellable] = []
    private var fetchResultsController: NSFetchedResultsController<BasePost>!

    init(blog: Blog,
         filters: PostListFilterSettings,
         coreDataStack: CoreDataStackSwift = ContextManager.shared
    ) {
        self.blog = blog
        self.filters = filters
        self.coreDataStack = coreDataStack
        self.postRepository = PostRepository(coreDataStack: coreDataStack)
        super.init()

        fetchResultsController = NSFetchedResultsController(
            fetchRequest: makeFetchRequest(searchTerm: ""),
            managedObjectContext: coreDataStack.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchResultsController.delegate = self

        $searchTerm.dropFirst().sink { [weak self] in
            self?.performLocalSearch(with: $0)
        }.store(in: &cancellables)

        $searchTerm
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .removeDuplicates()
            .filter { $0.count > 1 }
            .sink { [weak self] in
                self?.syncPostsMatchingSearchTerm($0)
        }.store(in: &cancellables)
    }

    // MARK: - Data Source

    var numberOfPosts: Int {
        fetchResultsController.fetchedObjects?.count ?? 0
    }

    func posts(at indexPath: IndexPath) -> BasePost {
        fetchResultsController.object(at: indexPath)
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objectDidChange?()
    }

    // MARK: - Local Search

    private func performLocalSearch(with searchTerm: String) {
        fetchResultsController.fetchRequest.predicate = makePredicate(searchTerm: searchTerm)
        do {
            try fetchResultsController.performFetch()
            objectDidChange?()
        } catch {
            assertionFailure("Failed to perform search: \(error)")
        }
    }

    private func makeFetchRequest(searchTerm: String) -> NSFetchRequest<BasePost> {
        let request = NSFetchRequest<BasePost>(entityName: makeEntityName())
        request.predicate = makePredicate(searchTerm: searchTerm)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AbstractPost.date_created_gmt, ascending: false)]
        request.fetchBatchSize = 40
        return request
    }

    private func makeEntityName() -> String {
        switch filters.postType {
        case .post: return String(describing: Post.self)
        case .page: return String(describing: Page.self)
        default: fatalError("Unsupported post type: \(filters.postType)")
        }
    }

    private func makePredicate(searchTerm: String) -> NSPredicate {
        var predicates = [NSPredicate]()

        // Show all original posts without a revision & revision posts.
        predicates.append(NSPredicate(format: "blog = %@ && revision = nil", blog))
        if filters.shouldShowOnlyMyPosts(), let userID = blog.userID {
            // Brand new local drafts have an authorID of 0.
            predicates.append(NSPredicate(format: "authorID = %@ || authorID = 0", userID))
        }
        predicates.append(NSPredicate(format: "postTitle CONTAINS[cd] %@", searchTerm))

        if filters.postType == .page, let predicate = PostSearchViewModel.makeHomepagePredicate(for: blog) {
            predicates.append(predicate)
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    static func makeHomepagePredicate(for blog: Blog) -> NSPredicate? {
        guard RemoteFeatureFlag.siteEditorMVP.enabled(),
           blog.blockEditorSettings?.isFSETheme ?? false,
           let homepageID = blog.homepagePageID,
           let homepageType = blog.homepageType,
              homepageType == .page else {
            return nil
        }
        return NSPredicate(format: "postID != %i", homepageID)
    }

    // MARK: - Remote Search (Sync)

    private func syncPostsMatchingSearchTerm(_ searchTerm: String) {
        let postType: AbstractPost.Type
        switch filters.postType {
        case .post: postType = Post.self
        case .page: postType = Page.self
        default:
            fatalError("Unsupported post type: \(filters.postType)")
        }

        let author = filters.shouldShowOnlyMyPosts() ? blog.userID : nil
        let blogID = TaggedManagedObjectID(blog)
        Task {
            do {
                _ = try await postRepository.search(
                    type: postType,
                    input: searchTerm,
                    statuses: [],
                    authorUserID: author,
                    limit: 20,
                    orderBy: .byDate,
                    descending: true,
                    in: blogID
                )
            } catch {
                DDLogError("Failed to search \(filters.postType): \(error)")
            }
        }
    }
}
