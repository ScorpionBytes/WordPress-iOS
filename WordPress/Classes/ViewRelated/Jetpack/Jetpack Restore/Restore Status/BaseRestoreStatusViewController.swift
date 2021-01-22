import Foundation
import CocoaLumberjack
import WordPressShared

struct JetpackRestoreStatusConfiguration {
    let title: String
    let iconImage: UIImage
    let messageTitle: String
    let messageDescription: String
    let hint: String
    let primaryButtonTitle: String
    let placeholderProgressTitle: String?
    let progressDescription: String?
}

class BaseRestoreStatusViewController: UIViewController {

    // MARK: - Public Properties

    lazy var statusView: RestoreStatusView = {
        let statusView = RestoreStatusView.loadFromNib()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        return statusView
    }()

    // MARK: - Private Properties

    private(set) var site: JetpackSiteRef
    private(set) var activity: Activity
    private(set) var store: ActivityStore
    private(set) var configuration: JetpackRestoreStatusConfiguration

    private lazy var dateFormatter: DateFormatter = {
        return ActivityDateFormatting.mediumDateFormatterWithTime(for: site)
    }()

    // MARK: - Initialization

    init(site: JetpackSiteRef, activity: Activity, store: ActivityStore) {
        fatalError("A configuration struct needs to be provided")
    }

    init(site: JetpackSiteRef,
         activity: Activity,
         store: ActivityStore,
         configuration: JetpackRestoreStatusConfiguration) {
        self.site = site
        self.activity = activity
        self.store = store
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTitle()
        configureNavigation()
        configureRestoreStatusView()
    }

    // MARK: - Configure

    private func configureTitle() {
        title = configuration.title
    }

    private func configureNavigation() {
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                           target: self,
                                                           action: #selector(doneTapped))
    }

    private func configureRestoreStatusView() {
        let publishedDate = dateFormatter.string(from: activity.published)

        statusView.configure(
            iconImage: configuration.iconImage,
            title: configuration.messageTitle,
            description: String(format: configuration.messageDescription, publishedDate),
            primaryButtonTitle: configuration.primaryButtonTitle,
            hint: configuration.hint
        )

        statusView.update(progress: 0, progressTitle: configuration.placeholderProgressTitle, progressDescription: nil)

        statusView.primaryButtonHandler = { [weak self] in
            self?.dismiss(animated: true)
        }

        view.addSubview(statusView)
        view.pinSubviewToAllEdges(statusView)
    }

    @objc private func doneTapped() {
        self.dismiss(animated: true)
    }
}
