import Foundation

/// Dynamic implementation of `JetpackFullscreenOverlayViewModel` based on the general phase
/// Should be used for feature-specific and feature-collection overlays.
struct JetpackFullscreenOverlayGeneralViewModel: JetpackFullscreenOverlayViewModel {

    let phase: JetpackFeaturesRemovalCoordinator.GeneralPhase
    let source: JetpackFeaturesRemovalCoordinator.OverlaySource

    var shouldShowOverlay: Bool {
        switch (phase, source) {

        // Phase One: Only show feature-specific overlays
        case (.one, .stats):
            fallthrough
        case (.one, .notifications):
            fallthrough
        case (.one, .reader):
            return true

        // Phase Two: Only show feature-specific overlays
        case (.two, .stats):
            fallthrough
        case (.two, .notifications):
            fallthrough
        case (.two, .reader):
            return false // TODO: Change this to true when other phase 2 tasks are ready

        // Phase Three: Show all overlays
        case (.three, _):
            return false // TODO: Change this to true when other phase 3 tasks are ready

        // Phase Four: Show feature-collection overlays. Features are removed by this point so they are irrelevant.
        case (.four, _):
            return false // TODO: Change this to true when other phase 4 tasks are ready

        // New Users Phase: Show feature-collection overlays. Do not show on app-open. Features are removed by this point so they are irrelevant.
        case (.newUsers, .appOpen):
            return false
        case (.newUsers, _):
            return false // TODO: Change this to true when other new users phase tasks are ready

        default:
            return false
        }
    }

    var title: String {
        switch (phase, source) {
        // Phase One
        case (.one, .stats):
            return Strings.PhaseOne.Stats.title
        case (.one, .notifications):
            return Strings.PhaseOne.Notifications.title
        case (.one, .reader):
            return Strings.PhaseOne.Reader.title

        // Phase Two
        case (.two, .stats):
            return Strings.PhaseTwoAndThree.statsTitle
        case (.two, .notifications):
            return Strings.PhaseTwoAndThree.notificationsTitle
        case (.two, .reader):
            return Strings.PhaseTwoAndThree.readerTitle

        // Phase Three
        case (.three, .stats):
            return Strings.PhaseTwoAndThree.statsTitle
        case (.three, .notifications):
            return Strings.PhaseTwoAndThree.notificationsTitle
        case (.three, .reader):
            return Strings.PhaseTwoAndThree.readerTitle
        default:
            return ""
        }
    }

    var subtitle: String {
        switch (phase, source) {
        // Phase One
        case (.one, .stats):
            return Strings.PhaseOne.Stats.subtitle
        case (.one, .notifications):
            return Strings.PhaseOne.Notifications.subtitle
        case (.one, .reader):
            return Strings.PhaseOne.Reader.subtitle

        // Phase Two
        case (.two, _):
            fallthrough

        // Phase Three
        case (.three, _):
            return Strings.PhaseTwoAndThree.subtitle // TODO: inject date
        default:
            return ""
        }
    }

    var animationLtr: String {
        switch source {
        case .stats:
            return Constants.statsLogoAnimationLtr
        case .notifications:
            return Constants.notificationsLogoAnimationLtr
        case .reader:
            return Constants.readerLogoAnimationLtr
        case .card:
            fallthrough
        case .login:
            fallthrough
        case .appOpen:
            return "" // TODO: Add new animation when ready
        }
    }

    var animationRtl: String {
        switch source {
        case .stats:
            return Constants.statsLogoAnimationRtl
        case .notifications:
            return Constants.notificationsLogoAnimationRtl
        case .reader:
            return Constants.readerLogoAnimationRtl
        case .card:
            fallthrough
        case .login:
            fallthrough
        case .appOpen:
            return "" // TODO: Add new animation when ready
        }
    }

    var footnote: String? {
        switch phase {
        case .one:
            return nil
        default:
            return nil
        }
    }

    var shouldShowLearnMoreButton: Bool {
        switch phase {
        case .one:
            return false
        case .two:
            return true
        case .three:
            return true
        default:
            return false
        }
    }

    var switchButtonText: String {
        switch phase {
        case .one:
            return Strings.General.earlyPhasesSwitchButtonTitle
        default:
            return ""
        }
    }

    var continueButtonText: String? {
        switch source {
        case .stats:
            return Strings.General.statsContinueButtonTitle
        case .notifications:
            return Strings.General.notificationsContinueButtonTitle
        case .reader:
            return Strings.General.readerContinueButtonTitle
        default:
            return nil
        }
    }

    var shouldShowCloseButton: Bool {
        switch phase {
        case .one:
            return true
        default:
            return false
        }
    }

    var analyticsSource: String {
        return source.rawValue
    }

    var onDismiss: JetpackOverlayDismissCallback?
}

private extension JetpackFullscreenOverlayGeneralViewModel {
    enum Constants {
        static let statsLogoAnimationLtr = "JetpackStatsLogoAnimation_ltr"
        static let statsLogoAnimationRtl = "JetpackStatsLogoAnimation_rtl"
        static let readerLogoAnimationLtr = "JetpackReaderLogoAnimation_ltr"
        static let readerLogoAnimationRtl = "JetpackReaderLogoAnimation_rtl"
        static let notificationsLogoAnimationLtr = "JetpackNotificationsLogoAnimation_ltr"
        static let notificationsLogoAnimationRtl = "JetpackNotificationsLogoAnimation_rtl"
    }

    enum Strings {

        enum General {
            static let earlyPhasesSwitchButtonTitle = NSLocalizedString("jetpack.fullscreen.overlay.early.switch.title",
                                                                        value: "Switch to the new Jetpack app",
                                                                        comment: "Title of a button that navigates the user to the Jetpack app if installed, or to the app store.")
            static let statsContinueButtonTitle = NSLocalizedString("jetpack.fullscreen.overlay.stats.continue.title",
                                                                    value: "Continue to Stats",
                                                                    comment: "Title of a button that dismisses an overlay and displays the Stats screen.")
            static let readerContinueButtonTitle = NSLocalizedString("jetpack.fullscreen.overlay.reader.continue.title",
                                                                     value: "Continue to Reader",
                                                                     comment: "Title of a button that dismisses an overlay and displays the Reader screen.")
            static let notificationsContinueButtonTitle = NSLocalizedString("jetpack.fullscreen.overlay.notifications.continue.title",
                                                                            value: "Continue to Notifications",
                                                                            comment: "Title of a button that dismisses an overlay and displays the Notifications screen.")
        }

        enum PhaseOne {

            enum Stats {
                static let title = NSLocalizedString("jetpack.fullscreen.overlay.phaseOne.stats.title",
                                                     value: "Get your stats using the new Jetpack app",
                                                     comment: "Title of a screen displayed when the user accesses the Stats screen from the WordPress app. The screen showcases the Jetpack app.")
                static let subtitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseOne.stats.subtitle",
                                                     value: "Switch to the Jetpack app to watch your site’s traffic grow with stats and insights.",
                                                     comment: "Subtitle of a screen displayed when the user accesses the Stats screen from the WordPress app. The screen showcases the Jetpack app.")
            }

            enum Reader {
                static let title = NSLocalizedString("jetpack.fullscreen.overlay.phaseOne.reader.title",
                                                     value: "Follow any site with the Jetpack app",
                                                     comment: "Title of a screen displayed when the user accesses the Reader screen from the WordPress app. The screen showcases the Jetpack app.")
                static let subtitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseOne.reader.subtitle",
                                                     value: "Switch to the Jetpack app to find, follow, and like all your favorite sites and posts with Reader.",
                                                     comment: "Subtitle of a screen displayed when the user accesses the Reader screen from the WordPress app. The screen showcases the Jetpack app.")
            }

            enum Notifications {
                static let title = NSLocalizedString("jetpack.fullscreen.overlay.phaseOne.notifications.title",
                                                     value: "Get your notifications with the Jetpack app",
                                                     comment: "Title of a screen displayed when the user accesses the Notifications screen from the WordPress app. The screen showcases the Jetpack app.")
                static let subtitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseOne.notifications.subtitle",
                                                     value: "Switch to the Jetpack app to keep recieving real-time notifications on your device.",
                                                     comment: "Subtitle of a screen displayed when the user accesses the Notifications screen from the WordPress app. The screen showcases the Jetpack app.")
            }
        }

        enum PhaseTwoAndThree {
            static let statsTitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseTwoAndThree.stats.title",
                                                 value: "Stats are moving to the Jetpack app",
                                                 comment: "Title of a screen displayed when the user accesses the Stats screen from the WordPress app. The screen showcases the Jetpack app.")
            static let readerTitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseTwoAndThree.reader.title",
                                                 value: "Reader is moving to the Jetpack app",
                                                 comment: "Title of a screen displayed when the user accesses the Reader screen from the WordPress app. The screen showcases the Jetpack app.")
            static let notificationsTitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseTwoAndThree.notifications.title",
                                                 value: "Notifications are moving to Jetpack",
                                                 comment: "Title of a screen displayed when the user accesses the Notifications screen from the WordPress app. The screen showcases the Jetpack app.")
            static let subtitle = NSLocalizedString("jetpack.fullscreen.overlay.phaseTwoAndThree.subtitle",
                                                 value: "Stats, Reader, Notifications and other Jetpack powered features will be removed from the WordPress app on %@.",
                                                 comment: "Subtitle of a screen displayed when the user accesses a Jetpack-powered feature from the WordPress app. The '%@' characters are a placeholder for the date the features will be removed.")
        }
    }
}
