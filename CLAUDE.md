# Claude Code Rules

## Project Context

This is **Seans** — a native iOS app (iPhone & iPad) for a single therapist practice in Ukraine. Built with View-Only (VO) architecture. Target iOS 17.6+.

The core thesis: SwiftUI View IS the ViewModel. It controls state, mutation, and UI binding. The body is the only true UI part — everything else in a View is effectively a ViewModel. Extracting UI-adjacent logic into separate Observable ViewModels unnecessarily limits SwiftUI's built-in capabilities and creates unnecessary complexity.

---

## Architecture Overview

### View-Only with @Observable Repositories

The architecture has three layers. Repositories handle business logic and data management as `@Observable` classes. StatefulViews act as ViewModels, communicating with repositories and managing UI state. StatelessViews are pure UI components receiving data via init parameters.

### View Hierarchy

**Screen** handles navigation logic only. It owns toolbar and navigation chrome and composes StatefulViews. It knows nothing about business logic or UI state.

**StatefulView** is the smart View that acts as the ViewModel. It communicates with repositories, manages UI-adjacent state, and passes data down to StatelessViews. It should not contain navigation logic.

**StatelessView** is dumb UI. It has no state and no side effects. It is rendered purely from data passed in via init parameters.

### Navigation with Stage and Flow

**Stage** is the top-level orchestrator of the entire app. It manages super-navigation between Flows and decides which Flow is active. It is a relatively simple View executing if-else logic to switch between Flows.

**Flow** is a View one level above Screen. It combines the UI and logic for creating and orchestrating the Screens that belong to it. Each Flow owns its own navigation stack and an encapsulated Environment. When a Flow is destroyed, all its associated services and state are released from memory.

Examples for Seans: `AuthFlow` for sign-in and onboarding, `ClientFlow` for client-facing features (booking, journal, calendar), `TherapistFlow` for therapist-only features (availability, client management, session notes).

### StatelessView Purity

StatelessViews should remain pure for clarity and testability. They receive only plain value types — `String`, `Int`, model structs — via `init`. Keep business logic out of StatelessViews.

### Repository Granularity

Split repositories by domain — `BookingRepository`, `JournalRepository`, `UserRepository` — and inject each only at the level of the hierarchy that actually needs it. With `@Observable`, re-renders are precise (only views reading a changed property re-render), but focused repositories still improve code organization and testability.

---

## Repository Rules

Repositories are `@Observable` classes named as `{Domain}Repository`.

```swift
@Observable
@MainActor
final class BookingRepository {
    var slots: [TimeSlot] = []
    var isLoading = false

    init() {
        Task { await load() }
    }

    func load() async { ... }
}
```

Repositories should auto-start. If data loading is expected, begin loading immediately on init, asynchronously — use `Task { await load() }` inside `init`.

Create repository instances via `@State var repo = MyRepository()` in the View that roots the hierarchy where it is needed.

Pass repositories down via `.environment(repo)` to child views, and receive them with `@Environment(MyRepository.self) var repo`.

Repository creation and initial data load happens at the hierarchy level where the data is needed. For shared data, this is often at the Flow level.

Use `@MainActor` for repositories that drive UI updates.

---

## iOS 17+ Features

### @Observable Macro

Use `@Observable` for all repositories and shared state objects. This provides precise re-renders — only views that read a changed property re-render.

```swift
@Observable
final class UserRepository {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
}
```

### Property Wrappers

Use `@State` for repository ownership in Views. Use `@Environment` for environment-injected repositories. Use `@Bindable` when you need bindings to `@Observable` object properties.

```swift
struct ClientFlow: View {
    @State var bookingRepo = BookingRepository()

    var body: some View {
        SomeScreen()
            .environment(bookingRepo)
    }
}

struct SomeScreen: View {
    @Environment(BookingRepository.self) var bookingRepo

    var body: some View {
        @Bindable var repo = bookingRepo
        TextField("Notes", text: $repo.notes)
    }
}
```

### NavigationStack

Use `NavigationStack` with `navigationDestination(for:)` for type-safe navigation. Never use deprecated `NavigationView`.

### Swift Concurrency

Full support for `async/await`, `async let`, `TaskGroup`, actors, and `AsyncStream`.

### Typed Throws

Typed throws (`throws(MyError)`) require **Swift 6+ / Xcode 16+**. Use them for precise error handling.

```swift
func fetchBookings() throws(BookingError) { ... }
```

### Swift Testing Framework

Unit and integration tests use **Swift Testing** (`@Test`, `#expect`, `#require`, parameterized tests).

**UI tests must stay on XCTest** — Swift Testing has no UI-testing support.

### SwiftData

Consider SwiftData for local persistence (iOS 17+). Alternative to Core Data with cleaner Swift-native syntax.

---

## What NOT to Do

Do NOT create separate ViewModel classes for new features. Use View as ViewModel.

Do NOT use `ObservableObject` or `@Published`. Use `@Observable` (iOS 17+).

Do NOT create singletons for state management. Use Environment-scoped repositories.

Do NOT put business logic in StatelessViews.

Do NOT create Views over 300 lines. Break them into smaller components.

Do NOT use nested closures more than 2 levels deep.

Do NOT use force unwrapping except in tests or previews.

Do NOT use callback hell. Use async/await.

Do NOT add unnecessary dependencies. Prefer native APIs.

Do NOT use `NavigationView`. Use `NavigationStack`.

---

## Swift Best Practices

### Code Clarity Over Comments

Write self-documenting code with descriptive names. Extract complex logic into well-named functions. Only comment when logic is genuinely non-obvious or explains *why*. Prefer code refactoring over explanatory comments.

### Naming Conventions

Types and Protocols use `PascalCase`. Functions, variables, and properties use `camelCase`. Boolean properties start with `is`, `has`, `should`, or `can`. Action functions use imperative verbs: `fetch`, `update`, `handle`. Repositories follow the `{Domain}Repository` pattern.

### Type Safety

Prefer `let` over `var` for immutability. Never force unwrap except in tests or previews. Use `guard` for early returns and unwrapping. Use `if let value` shorthand (available Swift 5.7+, iOS 16+). Leverage enums for state management and type-safe APIs.

### Concurrency

Use `@MainActor` for UI-related code and repositories that drive UI. Prefer structured concurrency with `async let` and `TaskGroup` over plain `Task` blocks. Handle cancellation with `Task.isCancelled` checks. Use `AsyncStream` for continuous value streams.

### Error Handling

Create specific error enums for each domain. Avoid catching generic `Error` at low levels. Propagate errors up and handle at the appropriate level. If on Swift 6 + Xcode 16, typed throws are encouraged.

### Memory Management

Mark closures with `[weak self]` or `[unowned self]` appropriately. Use value types (structs) by default. Prefer composition over inheritance.

---

## Code Organization

### Project Structure

```
Seans/
├── App/
│   └── SeansApp.swift
├── Flows/
│   ├── AuthFlow/
│   ├── ClientFlow/
│   └── TherapistFlow/
├── Features/
│   ├── Auth/
│   ├── Booking/
│   ├── Journal/
│   ├── Calendar/
│   └── ClientManagement/
├── Shared/
│   ├── Domain/          # Models, entities
│   ├── Data/            # Repositories, services
│   ├── UI/              # Shared UI components
│   └── Utilities/
└── Resources/
```

### Dependency Injection

Primary DI mechanism is SwiftUI Environment via `.environmentObject()`. Repositories are placed in Environment at the Flow level where needed. Pass dependencies explicitly through initializers for non-View code. Create protocol abstractions for services to enable testing. Make dependencies mockable for testing.

---

## SwiftUI Best Practices

### View as ViewModel

SwiftUI View IS the ViewModel. Do not create separate ViewModel classes. Use `@State` for view-local state and repository ownership. Use `@Environment` for shared repositories and services. Use `@Binding` for two-way data flow to child views. Use `@Bindable` to create bindings from `@Observable` objects. The `body` property is the only pure UI part of a View.

### View Composition

Break large views into smaller, reusable components. Use `@ViewBuilder` for conditional view construction. Prefer computed properties over functions for subviews. Pass only needed data down to stateless child views.

### Performance

With `@Observable`, re-renders are precise — only views that read a changed property re-render. Still keep repositories focused and granular for code organization. Use `LazyVStack` and `LazyHStack` for large lists. Avoid expensive operations in `body`. Implement proper list identity with the `id` parameter.

---

## Testing

### Unit Tests

Test Repositories in isolation. Mock all external dependencies including network and storage. Use async test methods for async code. Test error paths, not just happy paths.

### Test Frameworks

**Unit & integration tests: Swift Testing.** Prefer `struct` suites over `XCTestCase` classes, `init`/`deinit` over `setUp`/`tearDown`, `#expect`/`#require` over `XCTAssert`, and parameterized tests.

**UI tests: XCTest** (Swift Testing does not support UI testing).

Use `@MainActor` on suites/tests that touch UI-related code. Create test helpers in test targets only, not the main target.

---

## Security

### Credentials Management

Never hardcode API keys, tokens, or secrets. Use Keychain Services for secure token storage (especially Monobank merchant tokens). Clear sensitive data from memory after use. Use HTTPS for all network requests.

### Data Validation

Validate all user input before processing. Sanitize data from external sources. Use type-safe APIs to prevent invalid states.

### Biometric Security

Use LocalAuthentication framework for Face ID / Touch ID. Store sensitive journal entries with appropriate encryption. Respect user privacy settings for note sharing.

---

## Performance Optimization

Avoid premature optimization — measure first with Instruments. Use `lazy` for expensive computed properties. Implement pagination for large data sets. Cache network responses when appropriate. Use background queues for heavy processing.

---

## Build Configuration

Use `DEBUG` flag for development-only code. Remove all `print` statements in production; use `os_log` or `Logger` instead. Configure different API endpoints per environment using xcconfig files or a build-time configuration enum.

---

## Domain-Specific Notes

### Repositories for Seans

- `UserRepository` — current user, role (client/therapist), auth state
- `BookingRepository` — time slots, reservations, confirmed bookings
- `JournalRepository` — client journal entries, privacy flags
- `CalendarRepository` — EventKit and Google Calendar sync
- `PaymentRepository` — Monobank invoice handling, payment status

### Flows for Seans

- `AuthFlow` — Apple Sign-In, role selection, onboarding
- `ClientFlow` — booking, journal, mood tracking, calendar
- `TherapistFlow` — availability management, client list, session notes
