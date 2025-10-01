# Email System - Best Practices & Guidelines

## 🎯 Architecture Principles

### 1. Single Responsibility Principle (SRP)

Each service should have **one reason to change**:

✅ **Good Example:**
```swift
// EmailAuthService: ONLY handles authentication
class EmailAuthService {
    func authenticateWithGoogle() async throws -> EmailAccount
    func refreshToken() async throws -> String
}

// EmailNetworkService: ONLY handles network calls
class EmailNetworkService {
    func fetchEmails() async throws -> [EmailMessage]
    func sendEmail() async throws
}
```

❌ **Bad Example:**
```swift
// God Object: does everything
class EmailService {
    func authenticate() { }
    func fetchEmails() { }
    func cacheEmails() { }
    func categorizeEmails() { }
    func sendEmail() { }
    func parseHTML() { }
    // ... 50 more methods
}
```

### 2. Dependency Injection

Always inject dependencies instead of creating them internally:

✅ **Good Example:**
```swift
class RefactoredEmailService {
    private let authService: EmailAuthService
    private let networkService: EmailNetworkService

    init(
        authService: EmailAuthService,
        networkService: EmailNetworkService
    ) {
        self.authService = authService
        self.networkService = networkService
    }
}

// Testing
let mockAuth = MockAuthService()
let service = RefactoredEmailService(authService: mockAuth)
```

❌ **Bad Example:**
```swift
class EmailService {
    private let authService = EmailAuthService() // Hard-coded!
    private let networkService = EmailNetworkService() // Can't test!
}
```

### 3. Immutability When Possible

Use `let` and `private(set)` to prevent unexpected mutations:

✅ **Good Example:**
```swift
@Published public private(set) var emails: [EmailMessage] = []

func loadEmails() {
    // Only the service can modify emails
    self.emails = newEmails
}
```

❌ **Bad Example:**
```swift
@Published public var emails: [EmailMessage] = []

// Anyone can modify this!
emailService.emails = []  // Dangerous
```

### 4. Smart Caching Strategy

Use merge instead of replace to preserve local state:

✅ **Good Example:**
```swift
func mergeEmails(_ newEmails: [EmailMessage]) -> [EmailMessage] {
    var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

    for email in newEmails {
        dict[email.id] = email  // Update or add
    }

    return Array(dict.values).sorted { $0.date > $1.date }
}
```

❌ **Bad Example:**
```swift
func loadEmails() {
    self.emails = fetchedEmails  // Loses local changes!
}
```

## 🔧 Implementation Guidelines

### State Management

**Use @Published for Observable State:**
```swift
@Published public private(set) var emails: [EmailMessage]
@Published public private(set) var isLoading: Bool
@Published public var error: String?
```

**Use @MainActor for UI-Bound Classes:**
```swift
@MainActor
public final class EmailListViewModel: ObservableObject {
    // All UI updates happen on main thread
}
```

### Async/Await Best Practices

✅ **Good: Clean Async Flow**
```swift
func loadEmails() async {
    isLoading = true
    defer { isLoading = false }

    do {
        let emails = try await networkService.fetchEmails()
        self.emails = cacheManager.mergeEmails(emails)
    } catch {
        self.error = error.localizedDescription
    }
}
```

❌ **Bad: Callback Hell**
```swift
func loadEmails(completion: @escaping (Result<[EmailMessage], Error>) -> Void) {
    networkService.fetchEmails { result in
        switch result {
        case .success(let emails):
            self.cacheManager.saveEmails(emails) { cacheResult in
                // Nested callbacks...
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

### Error Handling

**Use Typed Errors:**
```swift
enum EmailError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to access your emails"
        case .networkError(let message):
            return "Network error: \(message)"
        case .tokenExpired:
            return "Session expired. Please sign in again"
        }
    }
}
```

**Handle Errors Gracefully:**
```swift
do {
    try await emailService.deleteEmail(id)
} catch EmailError.notAuthenticated {
    showLoginPrompt()
} catch EmailError.networkError(let msg) {
    showRetryAlert(message: msg)
} catch {
    showGenericError(error)
}
```

### Debouncing & Rate Limiting

**Implement Smart Debouncing:**
```swift
private var lastLoadTime: Date?
private let minimumLoadInterval: TimeInterval = 30.0

func loadEmails() async {
    // Check debouncing
    if let lastLoad = lastLoadTime {
        let elapsed = Date().timeIntervalSince(lastLoad)
        if elapsed < minimumLoadInterval {
            print("Debouncing: wait \(minimumLoadInterval - elapsed)s")
            return
        }
    }

    // Proceed with load
    lastLoadTime = Date()
    // ...
}
```

**Force Refresh When Needed:**
```swift
func forceRefresh() async {
    lastLoadTime = nil  // Reset debounce
    await loadEmails()
}
```

## 🧪 Testing Best Practices

### Unit Testing with Mocks

```swift
// Protocol for testability
protocol EmailAuthServiceProtocol {
    var isAuthenticated: Bool { get }
    func authenticate() async throws -> EmailAccount
}

// Mock implementation
class MockAuthService: EmailAuthServiceProtocol {
    var isAuthenticated = false
    var shouldFail = false

    func authenticate() async throws -> EmailAccount {
        if shouldFail {
            throw EmailError.notAuthenticated
        }
        isAuthenticated = true
        return EmailAccount(/* ... */)
    }
}

// Test
func testAuthentication() async {
    let mock = MockAuthService()
    let service = RefactoredEmailService(authService: mock)

    await service.authenticateWithGoogle()

    XCTAssertTrue(mock.isAuthenticated)
}
```

### Integration Testing

```swift
func testFullEmailFlow() async {
    // 1. Authenticate
    await emailService.authenticateWithGoogle()
    XCTAssertTrue(emailService.isAuthenticated)

    // 2. Load emails
    await emailService.loadEmails()
    XCTAssertFalse(emailService.emails.isEmpty)

    // 3. Mark as read
    let firstEmail = emailService.emails.first!
    await emailService.markEmailAsRead(firstEmail.id)
    XCTAssertTrue(emailService.emails.first!.isRead)
}
```

## 🎨 UI/UX Best Practices

### Loading States

```swift
struct EmailListView: View {
    @ObservedObject var viewModel: EmailListViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading emails...")
            } else if viewModel.filteredEmails.isEmpty {
                EmptyStateView()
            } else {
                EmailList(emails: viewModel.filteredEmails)
            }
        }
    }
}
```

### Error Feedback

```swift
.alert("Error", isPresented: $showError) {
    Button("Retry") {
        Task { await viewModel.refresh() }
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text(viewModel.error ?? "An error occurred")
}
```

### Accessibility

```swift
Button(action: { /* ... */ }) {
    Label("Mark as Read", systemImage: "envelope.open")
}
.accessibilityLabel("Mark email as read")
.accessibilityHint("Double tap to mark this email as read")
```

## 🔒 Security Best Practices

### Token Management

```swift
// ✅ Store tokens securely in Keychain
_ = keychainManager.saveAPIKey(token, for: "email_access_token")

// ❌ Never store in UserDefaults or as plain text
UserDefaults.standard.set(token, forKey: "token") // Insecure!
```

### Sensitive Data

```swift
// ✅ Clear sensitive data on logout
func disconnect() {
    currentAccount = nil
    emails = []
    _ = keychainManager.deleteAPIKey(for: "email_access_token")
    cacheManager.invalidateCache()
}

// ❌ Leave data in memory
func disconnect() {
    currentAccount = nil
    // emails still in memory!
}
```

## 📊 Performance Best Practices

### Lazy Loading

```swift
// Load emails in batches
func loadMoreEmails() async {
    let offset = emails.count
    let newEmails = try await networkService.fetchEmails(
        offset: offset,
        limit: 20
    )
    emails.append(contentsOf: newEmails)
}
```

### Memory Management

```swift
// Trim cache when it grows too large
private func trimCacheIfNeeded() {
    guard memoryCache.count > maxCacheSize else { return }

    let sorted = memoryCache.values.sorted { $0.date > $1.date }
    let toKeep = Array(sorted.prefix(maxCacheSize))
    memoryCache = Dictionary(uniqueKeysWithValues: toKeep.map { ($0.id, $0) })
}
```

### Background Tasks

```swift
// Use Task for async work
.task {
    await viewModel.refresh()
}

// Cancel tasks when view disappears
.task {
    for await _ in timer {
        await viewModel.checkForNewEmails()
    }
}
.onDisappear {
    // Task is automatically cancelled
}
```

## 🚀 Deployment Checklist

### Pre-Deployment

- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] No memory leaks (Instruments)
- [ ] Error handling covers all paths
- [ ] Accessibility tested with VoiceOver
- [ ] Performance tested with large datasets

### Migration Strategy

1. **Phase 1**: Deploy new services alongside old
2. **Phase 2**: Gradual adoption in new views
3. **Phase 3**: Migrate existing views
4. **Phase 4**: Remove old services

### Monitoring

```swift
// Add logging for key operations
func loadEmails() async {
    let start = Date()
    defer {
        let duration = Date().timeIntervalSince(start)
        print("📊 loadEmails took \(duration)s")
    }

    // ... load logic
}
```

## 📝 Code Review Checklist

- [ ] Follows Single Responsibility Principle
- [ ] Uses Dependency Injection
- [ ] Proper error handling
- [ ] No force unwraps (`!`) unless documented
- [ ] @MainActor where needed
- [ ] Async/await over callbacks
- [ ] Tests included for new features
- [ ] Documentation comments for public APIs
- [ ] No hardcoded strings/values
- [ ] Accessibility considerations

## 🎓 Common Pitfalls

### ❌ Pitfall 1: Forgetting @MainActor

```swift
// Crash: UI update on background thread
Task {
    let emails = await fetchEmails()
    self.emails = emails  // ❌ May crash
}

// ✅ Fix: Use @MainActor
@MainActor
func loadEmails() async {
    let emails = await fetchEmails()
    self.emails = emails  // ✅ Safe
}
```

### ❌ Pitfall 2: Retain Cycles

```swift
// Memory leak
networkService.fetch { result in
    self.emails = result  // ❌ Strong reference to self
}

// ✅ Fix: Use [weak self]
networkService.fetch { [weak self] result in
    self?.emails = result  // ✅ No leak
}
```

### ❌ Pitfall 3: Race Conditions

```swift
// Race condition
func loadEmails() async {
    isLoading = true
    emails = await fetchEmails()
    isLoading = false  // ❌ May be overwritten by concurrent call
}

// ✅ Fix: Use concurrent-safe flag
func loadEmails() async {
    guard !isCurrentlyLoading else { return }
    isCurrentlyLoading = true
    defer { isCurrentlyLoading = false }

    emails = await fetchEmails()
}
```

## 🔗 Additional Resources

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SwiftUI Best Practices](https://developer.apple.com/design/human-interface-guidelines/)

---

**Remember**: Good code is code that's easy to understand, test, and maintain. When in doubt, favor clarity over cleverness.
