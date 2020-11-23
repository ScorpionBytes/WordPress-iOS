import UIKit

@objc
class ReaderCoordinator: NSObject {
    let readerNavigationController: UINavigationController
    let readerSplitViewController: WPSplitViewController
    let readerMenuViewController: ReaderMenuViewController

    var failureBlock: (() -> Void)? = nil

    var source: UIViewController? = nil {
        didSet {
            let hasSource = source != nil
            let sourceIsTopViewController = source == topNavigationController?.topViewController

            isNavigatingFromSource = hasSource && (sourceIsTopViewController || readerIsNotCurrentlySelected)
        }
    }

    private var isNavigatingFromSource = false

    @objc
    init(readerNavigationController: UINavigationController,
         readerSplitViewController: WPSplitViewController,
         readerMenuViewController: ReaderMenuViewController) {
        self.readerNavigationController = readerNavigationController
        self.readerSplitViewController = readerSplitViewController
        self.readerMenuViewController = readerMenuViewController

        super.init()
    }
    private func prepareToNavigate() {
        WPTabBarController.sharedInstance().showReaderTab()

        topNavigationController?.popToRootViewController(animated: isNavigatingFromSource)
    }

    func showReaderTab() {
        WPTabBarController.sharedInstance().showReaderTab()
    }

    func showDiscover() {
        WPTabBarController.sharedInstance().switchToDiscover()
    }
    
    func showSearch() {
        WPTabBarController.sharedInstance().navigateToReaderSearch()
    }

    func showA8CTeam() {
        WPTabBarController.sharedInstance()?.switchToTopic(where: { topic in
            guard (topic as? ReaderTeamTopic)?.slug == ReaderTeamTopic.a8cTeamSlug else {
                return false
            }
            return true
        })
    }

    func showMyLikes() {
        WPTabBarController.sharedInstance().switchToMyLikes()
    }

    func showManageFollowing() {
        WPTabBarController.sharedInstance()?.switchToFollowedSites()
    }

    func showList(named listName: String, forUser user: String) {
        let context = ContextManager.sharedInstance().mainContext
        let service = ReaderTopicService(managedObjectContext: context)

        guard let topic = service.topicForList(named: listName, forUser: user) else {
            failureBlock?()
            return
        }

        WPTabBarController.sharedInstance()?.switchToTopic(where: { $0 == topic })
    }

    // here
    func showTag(named tagName: String) {
        if !isNavigatingFromSource, !FeatureFlag.newReaderNavigation.enabled {
            prepareToNavigate()
        }

        let remote = ReaderTopicServiceRemote(wordPressComRestApi: WordPressComRestApi.anonymousApi(userAgent: WPUserAgent.wordPress()))
        let slug = remote.slug(forTopicName: tagName) ?? tagName.lowercased()
        guard !FeatureFlag.newReaderNavigation.enabled else {
            getTagTopic(tagSlug: slug) { result in
                guard let topic = try? result.get() else { return }
                WPTabBarController.sharedInstance()?.navigateToReaderTag(topic)
            }
            return
        }
        let controller = ReaderStreamViewController.controllerWithTagSlug(slug)
        controller.streamLoadFailureBlock = failureBlock

        readerSplitViewController.showDetailViewController(controller, sender: nil)
        readerMenuViewController.deselectSelectedRow(animated: false)
    }

    private func getTagTopic(tagSlug: String, completion: @escaping (Result<ReaderTagTopic, Error>) -> Void) {
        let service = ReaderTopicService(managedObjectContext: ContextManager.sharedInstance().mainContext)
        service.tagTopicForTag(withSlug: tagSlug,
            success: { objectID in

                guard let objectID = objectID,
                    let topic = try? ContextManager.sharedInstance().mainContext.existingObject(with: objectID) as? ReaderTagTopic else {
                    DDLogError("Reader: Error retriving tag topic - invalid tag slug")
                    return
                }
                completion(.success(topic))
            },
            failure: { error in
                let defaultError = NSError(domain: "readerTagTopicError", code: -1, userInfo: nil)
                DDLogError("Reader: Error retriving tag topic - " + (error?.localizedDescription ?? "unknown failure reason"))
                completion(.failure(error ?? defaultError))
            })
    }

    func showStream(with siteID: Int, isFeed: Bool) {
        getSiteTopic(siteID: NSNumber(value: siteID), isFeed: isFeed) { result in
            guard let topic = try? result.get() else {
                return
            }
            
            WPTabBarController.sharedInstance()?.navigateToReaderSite(topic)
        }
    }

    private func getSiteTopic(siteID: NSNumber, isFeed: Bool, completion: @escaping (Result<ReaderSiteTopic, Error>) -> Void) {
        let service = ReaderTopicService(managedObjectContext: ContextManager.sharedInstance().mainContext)
        service.siteTopicForSite(withID: siteID,
        isFeed: isFeed,
        success: { objectID, isFollowing in

            guard let objectID = objectID,
                let topic = try? ContextManager.sharedInstance().mainContext.existingObject(with: objectID) as? ReaderSiteTopic else {
                DDLogError("Reader: Error retriving site topic - invalid Site Id")
                return
            }
            completion(.success(topic))
        },
        failure: { error in
            let defaultError = NSError(domain: "readerSiteTopicError", code: -1, userInfo: nil)
            DDLogError("Reader: Error retriving site topic - " + (error?.localizedDescription ?? "unknown failure reason"))
            completion(.failure(error ?? defaultError))
        })
    }

    func showPost(with postID: Int, for feedID: Int, isFeed: Bool) {
        let postLoadFailureBlock = { [weak self, failureBlock] in
            self?.readerNavigationController.popToRootViewController(animated: false)
            failureBlock?()
        }

        let detailViewController = ReaderDetailViewController.controllerWithPostID(postID as NSNumber,
                                                                                   siteID: feedID as NSNumber,
                                                                                   isFeed: isFeed)

        detailViewController.postLoadFailureBlock = postLoadFailureBlock
        WPTabBarController.sharedInstance().navigateToReader(detailViewController)
    }

    private var topNavigationController: UINavigationController? {
        guard readerIsNotCurrentlySelected == false else {
            return source?.navigationController
        }

        if readerMenuViewController.splitViewControllerIsHorizontallyCompact == false,
            let navigationController = readerSplitViewController.topDetailViewController?.navigationController {
            return navigationController
        }

        return readerNavigationController
    }

    private var readerIsNotCurrentlySelected: Bool {
        return WPTabBarController.sharedInstance().selectedViewController != readerSplitViewController
    }
}

extension ReaderTopicService {
    /// Returns an existing topic for the specified list, or creates one if one
    /// doesn't already exist.
    ///
    func topicForList(named listName: String, forUser user: String) -> ReaderListTopic? {
        let remote = ReaderTopicServiceRemote(wordPressComRestApi: WordPressComRestApi.anonymousApi(userAgent: WPUserAgent.wordPress()))
        let sanitizedListName = remote.slug(forTopicName: listName) ?? listName.lowercased()
        let sanitizedUser = user.lowercased()
        let path = remote.path(forEndpoint: "read/list/\(sanitizedUser)/\(sanitizedListName)/posts", withVersion: ._1_2)

        if let existingTopic = findContainingPath(path) as? ReaderListTopic {
            return existingTopic
        }

        let topic = ReaderListTopic(context: managedObjectContext)
        topic.title = listName
        topic.slug = sanitizedListName
        topic.owner = user
        topic.path = path

        return topic
    }
}
