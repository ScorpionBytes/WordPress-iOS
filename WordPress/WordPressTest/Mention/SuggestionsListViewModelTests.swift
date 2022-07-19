import XCTest

@testable import WordPress

class SuggestionsListViewModelTests: CoreDataTestCase {

    private var viewModel: SuggestionsListViewModel!
    private var userSuggestions: [UserSuggestion] = []

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        let context = self.contextManager.mainContext
        let blog = Blog(context: context)
        let viewModel = SuggestionsListViewModel(blog: blog)
        viewModel.context = context
        viewModel.suggestionType = .mention
        viewModel.userSuggestionService = SuggestionServiceMock(context: context)
        viewModel.siteSuggestionService = SiteSuggestionServiceMock(context: context)
        viewModel.reloadData()
        self.userSuggestions = viewModel.suggestions.users
        self.viewModel = viewModel
    }

    // MARK: - Test suggestions array

    /// Tests that the site suggestions array is loaded.
    func testSiteSuggestionsCount() {
        self.viewModel.suggestionType = .xpost
        self.viewModel.reloadData()
        XCTAssertEqual(viewModel.suggestions.sites.count, 5)
    }

    /// Tests that the user suggestions array is loaded.
    func testUserSuggestionsCount() {
        XCTAssertEqual(userSuggestions.count, 100)
    }

    // MARK: - Test searchSuggestions(forWord:) -> Bool

    /// Tests that the search result for site suggestions returns all suggestions when +  sign is provided
    func testSearchSiteSuggestionsWithPlusSign() {
        // Given
        let word = "+"
        self.viewModel.suggestionType = .xpost
        self.viewModel.reloadData()
        let expectedResult = viewModel.suggestions.sites.map { SuggestionViewModel(suggestion: $0) }

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(isEqual(expectedResult, viewModel.items))
        XCTAssertTrue(result)
    }

    /// Tests that the search result for site suggestions returns an exact match
    func testSearchSiteSuggestionsWithExactMatch() {
        // Given
        let word = "+bitwolf"
        self.viewModel.suggestionType = .xpost
        self.viewModel.reloadData()
        let expectedResult = SuggestionViewModel(suggestion: viewModel.suggestions.sites[2])

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(isEqual(expectedResult, viewModel.items[0]))
        XCTAssertTrue(result)
    }

    /// Tests that the seach result is empty when an empty word is provided
    func testSearchSuggestionsWithEmptyWord() {
        // Given
        let word = ""

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(result)
    }

    /// Tests that the seach result is not empty when @ sign is provided
    func testSearchSuggestionsWithAtSignWord() {
        // Given
        let word = "@"
        let expectedSuggestions = userSuggestions.map { SuggestionViewModel(suggestion: $0) }

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(isEqual(viewModel.items, expectedSuggestions))
        XCTAssertTrue(result)
    }

    /// Tests that the seach result has an exact match
    func testSearchSuggestionsWithExactMatch() throws {
        // Given
        let word = "@glegrandx"
        let expectedSuggestion = SuggestionViewModel(suggestion: userSuggestions[33])

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(viewModel.items.count == 1)
        XCTAssertTrue(isEqual(viewModel.items[0], expectedSuggestion))
        XCTAssertTrue(result)
    }

    /// Tests that the seach result has a few matches
    func testSearchSuggestionsWithPartialMatch() throws {
        // Given
        let word = "@ca"
        let expectedSuggestions = suggestionViewModels(fromIds: [17, 22, 38, 44, 71, 80, 81, 88, 91], in: userSuggestions)

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(viewModel.items.count == 9)
        XCTAssertTrue(isEqual(expectedSuggestions, viewModel.items))
        XCTAssertTrue(result)
    }

    /// Tests that the seach result has a few matches with one prominent suggestion at the top
    func testSearchSuggestionsWithPartialMatchAndOneProminentSuggestion() throws {
        // Given
        let word = "@ca"
        let expectedSuggestions = suggestionViewModels(fromIds: [88, 17, 22, 38, 44, 71, 80, 81, 91], in: userSuggestions)
        self.viewModel.prominentSuggestionsIds = [88]

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(viewModel.items.count == 9)
        XCTAssertTrue(isEqual(expectedSuggestions, viewModel.items))
        XCTAssertTrue(result)
    }

    /// Tests that the seach result has a few matches with two prominent suggestions at the top
    func testSearchSuggestionsWithPartialMatchAndTwoProminentSuggestion() throws {
        // Given
        let word = "@ca"
        let expectedSuggestions = suggestionViewModels(fromIds: [91, 88, 17, 22, 38, 44, 71, 80, 81], in: userSuggestions)
        self.viewModel.prominentSuggestionsIds = [91, 88]

        // When
        let result = self.viewModel.searchSuggestions(withWord: word)

        // Then
        XCTAssertTrue(viewModel.items.count == 9)
        XCTAssertTrue(isEqual(expectedSuggestions, viewModel.items))
        XCTAssertTrue(result)
    }

    // MARK: - Test prominentSuggestions(fromPostAuthorId:commentAuthorId:defaultAccountId:)

    /// Tests that a prominent suggestions array is created with a post author id and comment author id
    func testProminentSuggestionsWithPostAuthorAndCommentAuthor() {
        // Given
        let postAuthorId = NSNumber(value: 1)
        let commentAuthorId = NSNumber(value: 2)

        // When
        let result = SuggestionsTableView.prominentSuggestions(fromPostAuthorId: postAuthorId, commentAuthorId: commentAuthorId, defaultAccountId: nil)

        // Then
        XCTAssertEqual(result, [1, 2])
    }

    /// Tests that a default account is excluded from the prominent suggestions array
    func testDefaultAccountExcludedFromProminentSuggestions() {
        // Given
        let postAuthorId = NSNumber(value: 1)
        let commentAuthorId = NSNumber(value: 2)
        let accountId = NSNumber(value: 1)

        // When
        let result = SuggestionsTableView.prominentSuggestions(fromPostAuthorId: postAuthorId, commentAuthorId: commentAuthorId, defaultAccountId: accountId)

        // Then
        XCTAssertEqual(result, [2])
    }

    // MARK: - Helpers

    private func suggestionViewModels(fromIds ids: [Int], in userSuggestions: [UserSuggestion]) -> [SuggestionViewModel] {
        return ids.compactMap { id -> SuggestionViewModel? in
            let suggestion = userSuggestions.first(where: { $0.userID == NSNumber(value: id) })
            return suggestion == nil ? nil : SuggestionViewModel(suggestion: suggestion!)
        }
    }

    private func isEqual(_ left: SuggestionViewModel, _ right: SuggestionViewModel) -> Bool {
        return [left.title, left.subtitle, left.imageURL?.absoluteString] == [right.title, right.subtitle, right.imageURL?.absoluteString]
    }

    private func isEqual(_ left: [SuggestionViewModel], _ right: [SuggestionViewModel]) -> Bool {
        guard left.count == right.count else { return false }
        for (index, element) in left.enumerated() {
            guard !isEqual(element, right[index]) else { continue }
            return false
        }
        return true
    }

}
