import UIKit

class StatsRevampV2FeatureIntroduction: FeatureIntroductionViewController {

    var presenter: StatsRevampV2IntroductionPresenter?

    init() {
        let featureDescriptionView = StatsRevampV2FeatureDescriptionView.loadFromNib()
        featureDescriptionView.translatesAutoresizingMaskIntoConstraints = false

        let headerImage = UIImage.gridicon(.statsAlt, size: HeaderStyle.iconSize).withTintColor(.clear)

        super.init(headerTitle: HeaderStrings.title, headerSubtitle: "", headerImage: headerImage, featureDescriptionView: featureDescriptionView, primaryButtonTitle: ButtonStrings.showMe, secondaryButtonTitle: ButtonStrings.remindMe)

        featureIntroductionDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add the gradient after the image has been added to the view so the gradient is the correct size.
        addHeaderImageGradient()

        captureAnalyticsEvent(.statsInsightsAnnouncementShown)
    }
}

extension StatsRevampV2FeatureIntroduction: FeatureIntroductionDelegate {
    func primaryActionSelected() {
        presenter?.primaryButtonSelected()

        captureAnalyticsEvent(.statsInsightsAnnouncementConfirmed)
    }

    func secondaryActionSelected() {
        presenter?.secondaryButtonSelected()

        captureAnalyticsEvent(.statsInsightsAnnouncementDismissed)
    }

    func closeButtonWasTapped() {
        presenter?.dismissButtonSelected()

        captureAnalyticsEvent(.statsInsightsAnnouncementDismissed)
    }
}

private extension StatsRevampV2FeatureIntroduction {

    func addHeaderImageGradient() {
        // Based on https://stackoverflow.com/a/54096829
        let gradient = CAGradientLayer()

        gradient.colors = [
            HeaderStyle.startGradientColor.cgColor,
            HeaderStyle.endGradientColor.cgColor
        ]

        // Create a gradient from top to bottom.
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.frame = headerImageView.bounds

        // Add a mask to the gradient so the colors only apply to the image (and not the imageView).
        let mask = CALayer()
        mask.contents = headerImageView.image?.cgImage
        mask.frame = gradient.bounds
        gradient.mask = mask

        // Add the gradient as a sublayer to the imageView's layer.
        headerImageView.layer.addSublayer(gradient)
    }

    private func captureAnalyticsEvent(_ event: WPAnalyticsEvent) {
        WPAnalytics.track(event)
    }

    enum ButtonStrings {
        static let showMe = NSLocalizedString("Try it now", comment: "Button title to take user to the new Stats Insights screen.")
        static let remindMe = NSLocalizedString("Remind me later", comment: "Button title dismiss the Stats Insights feature announcement screen.")
    }

    enum HeaderStrings {
        static let title = NSLocalizedString("Insights update", comment: "Title displayed on the feature introduction view that announces the updated Stats Insight screen.")
    }

    enum HeaderStyle {
        static let iconSize = CGSize(width: 40, height: 40)
        static let startGradientColor: UIColor = .muriel(name: .blue, .shade5)
        static let endGradientColor: UIColor = .muriel(name: .blue, .shade50)
    }
}
