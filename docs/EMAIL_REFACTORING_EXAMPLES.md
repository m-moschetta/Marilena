# Email Refactoring - Usage Examples

## 📘 Practical Examples

### Example 1: Basic Setup - New Email List View

```swift
import SwiftUI

struct NewEmailListView: View {
    @StateObject private var emailService = RefactoredEmailService()
    @StateObject private var viewModel: EmailListViewModel

    init() {
        let service = RefactoredEmailService()
        _emailService = StateObject(wrappedValue: service)
        _viewModel = StateObject(wrappedValue: EmailListViewModel(emailService: service))
    }

    var body: some View {
        NavigationStack {
            List(viewModel.filteredEmails) { email in
                EmailRowView(email: email, viewModel: viewModel)
            }
            .navigationTitle("Email")
            .searchable(text: $viewModel.searchText)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await emailService.restoreAuthentication()
        }
    }
}
```

### Example 2: Email Row with Actions

```swift
struct EmailRowView: View {
    let email: EmailMessage
    @ObservedObject var viewModel: EmailListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(email.from)
                    .font(.subheadline)
                    .fontWeight(email.isRead ? .regular : .bold)

                Spacer()

                Text(viewModel.formatRelativeDate(email.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(email.subject)
                .font(.subheadline)
                .foregroundStyle(email.isRead ? .secondary : .primary)

            Text(email.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task {
                    await viewModel.toggleReadStatus(for: email)
                }
            } label: {
                Label("Read", systemImage: "envelope.open")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteEmail(email)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

### Example 3: Authentication Flow

```swift
struct EmailLoginView: View {
    @StateObject private var emailService = RefactoredEmailService()
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Connect Your Email")
                .font(.largeTitle)
                .fontWeight(.bold)

            Button {
                Task {
                    isAuthenticating = true
                    await emailService.authenticateWithGoogle()
                    isAuthenticating = false
                }
            } label: {
                HStack {
                    Image(systemName: "envelope.circle")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)

            Button {
                Task {
                    isAuthenticating = true
                    await emailService.authenticateWithMicrosoft()
                    isAuthenticating = false
                }
            } label: {
                HStack {
                    Image(systemName: "envelope.circle")
                    Text("Sign in with Microsoft")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.indigo)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)
        }
        .padding()
    }
}
```

### Example 4: Category Filtering

```swift
struct EmailCategoryFilters: View {
    @ObservedObject var viewModel: EmailListViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All emails
                CategoryChip(
                    title: "All",
                    icon: "envelope",
                    count: viewModel.getAllEmailsCount(),
                    isSelected: viewModel.selectedCategory == nil && !viewModel.showUncategorized
                ) {
                    viewModel.clearFilters()
                }

                // Work emails
                CategoryChip(
                    title: "Work",
                    icon: "briefcase",
                    count: viewModel.getCategoryCount(.work),
                    isSelected: viewModel.selectedCategory == .work
                ) {
                    viewModel.selectCategory(.work)
                }

                // Personal emails
                CategoryChip(
                    title: "Personal",
                    icon: "person",
                    count: viewModel.getCategoryCount(.personal),
                    isSelected: viewModel.selectedCategory == .personal
                ) {
                    viewModel.selectCategory(.personal)
                }

                // Uncategorized
                CategoryChip(
                    title: "Other",
                    icon: "tray",
                    count: viewModel.getUncategorizedCount(),
                    isSelected: viewModel.showUncategorized
                ) {
                    viewModel.selectUncategorized()
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}
```

### Example 5: Compose Email

```swift
struct ComposeEmailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var emailService = RefactoredEmailService()

    @State private var to = ""
    @State private var subject = ""
    @State private var body = ""
    @State private var isSending = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    TextField("To", text: $to)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section("Content") {
                    TextField("Subject", text: $subject)

                    TextEditor(text: $body)
                        .frame(minHeight: 200)
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            await sendEmail()
                        }
                    }
                    .disabled(to.isEmpty || subject.isEmpty || isSending)
                }
            }
        }
    }

    private func sendEmail() async {
        isSending = true
        error = nil

        do {
            try await emailService.sendEmail(
                to: to,
                subject: subject,
                body: body
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }
}
```

### Example 6: Threading/Conversations View

```swift
struct ConversationsView: View {
    @ObservedObject var viewModel: EmailListViewModel

    var body: some View {
        List(viewModel.filteredConversations) { conversation in
            NavigationLink(destination: ConversationDetailView(conversation: conversation)) {
                ConversationRow(conversation: conversation)
            }
            .swipeActions(edge: .leading) {
                Button {
                    Task {
                        await viewModel.markConversationAsRead(conversation)
                    }
                } label: {
                    Label("Read", systemImage: "envelope.open")
                }
                .tint(.blue)
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: EmailConversation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(.blue.gradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(conversation.participants.first?.prefix(1) ?? "?"))
                        .foregroundStyle(.white)
                        .font(.subheadline)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.subject)
                        .font(.subheadline)
                        .fontWeight(conversation.hasUnread ? .bold : .regular)
                        .lineLimit(1)

                    Spacer()

                    if conversation.messageCount > 1 {
                        Text("\(conversation.messageCount)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.blue))
                    }
                }

                Text(conversation.participantsDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let latest = conversation.latestMessage {
                    Text(latest.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if conversation.hasUnread {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 8)
            }
        }
    }
}
```

### Example 7: Unit Testing with DI

```swift
import XCTest
@testable import Marilena

class RefactoredEmailServiceTests: XCTestCase {
    var sut: RefactoredEmailService!
    var mockAuth: MockEmailAuthService!
    var mockNetwork: MockEmailNetworkService!
    var mockCache: MockEmailCacheManager!

    override func setUp() {
        super.setUp()

        mockAuth = MockEmailAuthService()
        mockNetwork = MockEmailNetworkService()
        mockCache = MockEmailCacheManager()

        sut = RefactoredEmailService(
            authService: mockAuth,
            networkService: mockNetwork,
            cacheManager: mockCache
        )
    }

    override func tearDown() {
        sut = nil
        mockAuth = nil
        mockNetwork = nil
        mockCache = nil

        super.tearDown()
    }

    func testLoadEmails_WhenAuthenticated_FetchesFromNetwork() async {
        // Given
        let mockAccount = EmailAccount(
            provider: .google,
            email: "test@gmail.com",
            accessToken: "token",
            refreshToken: nil,
            expiresAt: nil
        )
        mockAuth.currentAccount = mockAccount
        mockAuth.isAuthenticated = true

        let mockEmails = [
            EmailMessage(
                id: "1",
                from: "sender@test.com",
                to: ["test@gmail.com"],
                subject: "Test",
                body: "Body",
                date: Date(),
                isRead: false,
                hasAttachments: false,
                category: nil
            )
        ]
        mockNetwork.mockEmails = mockEmails

        // When
        await sut.loadEmails()

        // Then
        XCTAssertEqual(sut.emails.count, 1)
        XCTAssertEqual(sut.emails.first?.subject, "Test")
        XCTAssertTrue(mockNetwork.fetchEmailsCalled)
    }

    func testMarkAsRead_UpdatesLocalStateImmediately() async {
        // Given
        let email = EmailMessage(
            id: "1",
            from: "sender@test.com",
            to: ["test@gmail.com"],
            subject: "Test",
            body: "Body",
            date: Date(),
            isRead: false,
            hasAttachments: false,
            category: nil
        )
        await sut.emails.append(email)

        // When
        await sut.markEmailAsRead(email.id)

        // Then
        let updatedEmail = await sut.emails.first { $0.id == email.id }
        XCTAssertTrue(updatedEmail?.isRead ?? false)
    }
}

// MARK: - Mock Services

class MockEmailAuthService: EmailAuthService {
    var currentAccount: EmailAccount?
    var isAuthenticated = false
}

class MockEmailNetworkService: EmailNetworkService {
    var mockEmails: [EmailMessage] = []
    var fetchEmailsCalled = false

    override func fetchEmailsFromGmail(accessToken: String, maxResults: Int) async throws -> [EmailMessage] {
        fetchEmailsCalled = true
        return mockEmails
    }
}

class MockEmailCacheManager: EmailCacheManager {
    var cachedEmails: [String: EmailMessage] = [:]

    override func getEmail(id: String) -> EmailMessage? {
        return cachedEmails[id]
    }

    override func saveEmail(_ email: EmailMessage) {
        cachedEmails[email.id] = email
    }
}
```

### Example 8: Advanced - Custom Email Filter

```swift
extension EmailListViewModel {
    /// Custom filter: emails from last 7 days with attachments
    func loadRecentEmailsWithAttachments() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        filteredEmails = emailService.emails.filter { email in
            email.hasAttachments && email.date >= sevenDaysAgo
        }.sorted { $0.date > $1.date }
    }

    /// Custom filter: unread emails from specific sender
    func loadUnreadFrom(sender: String) {
        filteredEmails = emailService.emails.filter { email in
            !email.isRead && email.from.lowercased().contains(sender.lowercased())
        }.sorted { $0.date > $1.date }
    }
}
```

## 🎯 Key Takeaways

1. **Use ViewModel for UI Logic**: `EmailListViewModel` handles all business logic
2. **Leverage DI for Testing**: Mock services easily with dependency injection
3. **Reactive Updates**: `@Published` + `@ObservedObject` = automatic UI updates
4. **Async/Await**: Clean asynchronous code with Swift concurrency
5. **Separation**: Services don't know about views, views don't know about network

## 📚 Additional Resources

- [RefactoredEmailService.swift](../Marilena/Core/Email/Services/RefactoredEmailService.swift)
- [EmailListViewModel.swift](../Marilena/Features/Email/List/EmailListViewModel.swift)
- [Migration Guide](EMAIL_REFACTORING_MIGRATION.md)
- [Summary](EMAIL_REFACTORING_SUMMARY.md)
