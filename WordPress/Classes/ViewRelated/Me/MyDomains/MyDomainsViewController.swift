import UIKit

final class MyDomainsViewController: UIViewController {
    enum Action: String {
        case addToSite
        case purchase
        case transfer

        var title: String {
            switch self {
            case .addToSite:
                return NSLocalizedString(
                    "domain.management.fab.add.domain.title",
                    value: "Add domain to site",
                    comment: "Domain Management FAB Add Domain title"
                )
            case .purchase:
                return NSLocalizedString(
                    "domain.management.fab.purchase.domain.title",
                    value: "Purchase domain only",
                    comment: "Domain Management FAB Purchase Domain title"
                )
            case .transfer:
                return NSLocalizedString(
                    "domain.management.fab.transfer.domain.title",
                    value: "Transfer domain(s)",
                    comment: "Domain Management FAB Transfer Domain title"
                )
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Domains" // FIXME: Localize

        WPStyleGuide.configureColors(view: view, tableView: nil)
        navigationItem.rightBarButtonItem = .init(systemItem: .add)
        let addToSiteAction = menuAction(withTitle: Action.addToSite.title) { action in
            print("add to site")
        }
        let purchaseAction = menuAction(withTitle: Action.purchase.title) { action in
            print("purchase")
        }
        let transferAction = menuAction(withTitle: Action.transfer.title) { action in
            print("transfer")
        }

        let actions = [addToSiteAction, purchaseAction, transferAction]
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: .displayInline, children: actions)
        navigationItem.rightBarButtonItem?.menu = menu

    }

    private func menuAction(withTitle title: String, handler: UIActionHandler) -> UIAction {
        .init(
            title: title,
            image: nil,
            identifier: nil,
            discoverabilityTitle: nil,
            attributes: .init(),
            state: .mixed,
            handler: { (action) in
            // Perform action
        })
    }
}
