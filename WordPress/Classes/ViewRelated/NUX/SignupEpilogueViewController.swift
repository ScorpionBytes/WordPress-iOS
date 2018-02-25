import UIKit

class SignupEpilogueViewController: NUXViewController {

    // MARK: - Properties

    private var buttonViewController: NUXButtonViewController?
    private var updatedDisplayName: String?
    private var updatedPassword: String?

    // MARK: - View

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let vc = segue.destination as? NUXButtonViewController {
            buttonViewController = vc
            buttonViewController?.delegate = self
            buttonViewController?.setButtonTitles(primary: NSLocalizedString("Continue", comment: "Button text on site creation epilogue page to proceed to My Sites."))
        }

        if let vc = segue.destination as? SignupEpilogueTableViewController {
            vc.loginFields = loginFields
            vc.delegate = self
        }
    }

}

// MARK: - NUXButtonViewControllerDelegate

extension SignupEpilogueViewController: NUXButtonViewControllerDelegate {
    func primaryButtonPressed() {

        if updatedDisplayName != nil || updatedPassword != nil {
            updateUserInfo()
        } else {
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - SignupEpilogueTableViewControllerDelegate

extension SignupEpilogueViewController: SignupEpilogueTableViewControllerDelegate {
    func displayNameUpdated(newDisplayName: String) {
        updatedDisplayName = newDisplayName
    }

    func passwordUpdated(newPassword: String) {
        updatedPassword = newPassword
    }

}

// MARK: - Private Extension

private extension SignupEpilogueViewController {

    func updateUserInfo() {

        guard let updatedDisplayName = updatedDisplayName else {
            return
        }

        let context = ContextManager.sharedInstance().mainContext

        guard let defaultAccount = AccountService(managedObjectContext: context).defaultWordPressComAccount(),
        let restApi = defaultAccount.wordPressComRestApi else {
            return
        }

        let accountSettingService = AccountSettingsService(userID: defaultAccount.userID.intValue, api: restApi)
        let accountSettingsChange = AccountSettingsChange.displayName(updatedDisplayName)

        accountSettingService.saveChange(accountSettingsChange) {
            // If the password needs updating, do that.
            // If not, refresh the account so 'Me' tab info is correct.
            if let _ = self.updatedPassword {
                self.updatePassword()
            } else {
                self.refreshAccountDetails()
            }
        }
    }

    func updatePassword() {

        guard let updatedPassword = updatedPassword else {
            return
        }

        let context = ContextManager.sharedInstance().mainContext

        guard let defaultAccount = AccountService(managedObjectContext: context).defaultWordPressComAccount(),
            let restApi = defaultAccount.wordPressComRestApi else {
                return
        }

        let accountSettingService = AccountSettingsService(userID: defaultAccount.userID.intValue, api: restApi)

        accountSettingService.updatePassword(updatedPassword) {
            // Refresh the account so 'Me' tab info is correct.
            self.refreshAccountDetails()
        }
    }

    func refreshAccountDetails() {
        let context = ContextManager.sharedInstance().mainContext
        let service = AccountService(managedObjectContext: context)
        guard let account = service.defaultWordPressComAccount() else {
            self.navigationController?.dismiss(animated: true, completion: nil)
            return
        }
        service.updateUserDetails(for: account, success: { () in
            self.navigationController?.dismiss(animated: true, completion: nil)
        }, failure: { _ in
            self.navigationController?.dismiss(animated: true, completion: nil)
        })
    }

}
