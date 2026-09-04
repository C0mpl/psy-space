# PsySpace — Pet Project Concept & Architecture Breakdown

A native iOS app (iPhone & iPad) for a single therapist practice in Ukraine. The app connects one therapist with their clients, streamlining scheduling, payment processing via Monobank, session management, and therapeutic journaling.

---

## 1. Executive Summary & Value Proposition

* **For Clients:** A secure, friction-free environment to book appointments, pay via Monobank/Apple Pay, keep daily therapeutic notes, track emotional mood trends, and prepare for upcoming sessions.
* **For Therapist:** A lightweight practice management tool to set availability, manage client profiles and session history, view shared client notes, and track bookings — all from the same iOS app with elevated permissions.

---

## 2. Core Feature Matrix

### 2.1. Client Features

| Feature | Description | Status |
| :--- | :--- | :--- |
| **Smart Booking & Scheduling** | View therapist's availability (set in-app); book sessions with real-time slot availability. | ✅ Implemented |
| **Google Sign-In** | Secure authentication via Google account. | ✅ Implemented |
| **Monobank Payment Integration** | Integrated payment flow using Monobank API (invoices, Apple Pay/Google Pay via MonoPay, webhooks). | ✅ Implemented |
| **Calendar Sync** | Booked sessions sync to Google Calendar with Meet links; clients receive email invites. | ✅ Implemented |
| **Therapeutic Journal & Notes** | Private rich-text diary for thoughts, breakthroughs, and session prep notes. Voice message support. | ✅ Implemented |
| **Mood & Emotion Tracker** | Daily emotional state check-in using a 5-level scale with emoji representation. | ✅ Implemented |
| **Contextual Note Sharing** | Option to mark journal entries as shared for therapist review before sessions. | ✅ Implemented |
| **Privacy & Security** | Biometric lock (Face ID / Touch ID) + option to mark notes as strictly private. | ✅ Implemented |
| **Homework Assignments** | View and complete therapist-assigned homework, add responses, and control sharing with therapist. | ✅ Implemented |

### 2.2. Therapist Features (Same App, Elevated Role)

| Feature | Description | Status |
| :--- | :--- | :--- |
| **Availability Management** | Set working days, hours, session duration, and breaks directly in the app. | ✅ Implemented |
| **Real-time Booking Sync** | All bookings sync instantly via Firebase Firestore between therapist and clients. | ✅ Implemented |
| **Dashboard Stats** | View today's session count, upcoming sessions, and weekly schedule overview. | ✅ Implemented |
| **Calendar Sync** | Server-side Google Calendar sync with Meet links; toggle in settings. | ✅ Implemented |
| **Client Management** | View client list, session history, and shared journal entries. | ✅ Implemented |
| **Session Notes & Anamnesis** | Record session notes, hypotheses, and treatment observations per client. | ✅ Implemented |
| **Cancellation Policies** | Configurable cancellation windows (e.g., free up to 24h; partial/full retention after). | ✅ Implemented |
| **Homework & Materials** | Assign exercises with text instructions and PDF/link attachments. Clients can respond, mark as completed, and control sharing. | ✅ Implemented |

---

## 3. Tech Stack

### iOS App
* **Framework:** Native Swift / SwiftUI (iOS 17.6+)
* **Architecture:** View-Only (VO) — SwiftUI View IS the ViewModel. See `CLAUDE.md` for full documentation.
* **Observation:** `@Observable` macro (iOS 17+) for repositories and shared state
* **Local Storage:** SwiftData for user persistence
* **Design System:** Custom warm amber/honey color palette with accessibility support (@ScaledMetric)
* **Language:** Ukrainian (локалізація українською)

### Backend & Infrastructure
* **Backend:** Firebase Firestore — real-time database for availability and bookings sync
* **Authentication:** Firebase Auth with Google Sign-In
* **Data Sync:** Firestore listeners for real-time updates between therapist and clients

### Third-Party Integrations
* **Google Sign-In SDK:** OAuth 2.0 authentication flow ✅
* **Firebase Firestore:** Real-time NoSQL database ✅
* **Firebase Cloud Storage:** Audio file storage for voice messages ✅
* **Firebase Crashlytics:** Crash reporting (user-toggleable for privacy) ✅
* **Monobank API:** Invoice generation, cancellation, refunds, webhook handler ✅
* **Google Calendar:** Server-side integration via Cloud Functions with OAuth 2.0, auto-generates Google Meet links ✅
* **Apple Calendar:** EventKit integration as fallback ✅
* **Push Notifications:** Firebase Cloud Messaging (FCM) for booking confirmations, cancellations, and reschedules ✅
* **LocalAuthentication:** Face ID / Touch ID for journal privacy ✅

---

## 4. System Architecture & Data Flow

### Current Implementation

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      Stage.swift                           │ │
│  │              (Flow Orchestrator + Listeners)               │ │
│  └──────────────────────────┬─────────────────────────────────┘ │
│                             │                                   │
│         ┌───────────────────┼───────────────────┐               │
│         ▼                   ▼                   ▼               │
│  ┌─────────────┐    ┌─────────────┐    ┌──────────────┐        │
│  │  AuthFlow   │    │ ClientFlow  │    │TherapistFlow │        │
│  │ SignInScreen│    │ BookingTab  │    │ ScheduleTab  │        │
│  └─────────────┘    │ HistoryTab  │    │ ClientsTab   │        │
│                     │ ProfileTab  │    │ ProfileTab   │        │
│                     └─────────────┘    └──────────────┘        │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    @Observable Repositories                │ │
│  │  UserRepository │ AvailabilityRepository │ BookingRepository│ │
│  └──────────────────────────┬─────────────────────────────────┘ │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────┐
              │    Firebase Firestore     │
              │  ┌─────────────────────┐  │
              │  │   /availability     │  │  ← Therapist schedule settings
              │  │   /bookings         │  │  ← Client bookings (real-time sync)
              │  │   /pendingBookings  │  │  ← Unpaid booking holds
              │  │   /config/therapist │  │  ← Calendar OAuth tokens
              │  └─────────────────────┘  │
              └───────────────┬───────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Firebase Auth │    │Cloud Functions│    │     FCM       │
│(Google SignIn)│    │               │    │(Push Notifs)  │
└───────────────┘    │ • monobankWH  │    └───────────────┘
                     │ • calendarSync│
                     │ • cleanup jobs│
                     └───────┬───────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
       ┌───────────┐  ┌───────────┐  ┌───────────┐
       │ Monobank  │  │  Google   │  │  Google   │
       │   API     │  │ Calendar  │  │   Meet    │
       └───────────┘  └───────────┘  └───────────┘
```

### Role Assignment

The app uses email-based role assignment for simplicity (single therapist):

```swift
// In UserRepository.swift
private let therapistEmail = "therapist@example.com" // Configure actual email
let isTherapist = firebaseUser.email?.lowercased() == therapistEmail.lowercased()
```

### Real-time Data Sync

1. **Therapist sets availability** → Saved to Firestore `/availability` document
2. **Clients see updated slots** → Firestore listener pushes changes instantly
3. **Client books a slot** → Booking saved to Firestore `/bookings` collection
4. **Therapist sees new booking** → Firestore listener updates their dashboard

### Current: Payment & Booking Workflow

1. **Selection:** Client picks an open time slot from therapist's availability.
2. **Reservation:** The slot is temporarily held during payment.
3. **Invoice Creation:** App calls Monobank API to generate a payment invoice.
4. **Payment Execution:** Client pays via MonoPay (Apple Pay / card).
5. **Webhook Verification:** Cloud Function receives webhook confirming payment.
6. **Confirmation:**
   * Booking is confirmed in Firestore.
   * Push notification sent to both client and therapist.
   * Google Calendar event created with Meet link (if therapist enabled sync).
   * Email invites sent to therapist and client.

---

## 5. Project Structure

```
PsySpace/
├── PsySpaceApp.swift           # App entry point, Firebase init, Google Sign-In URL handling
├── Stage.swift                 # Flow orchestrator, repository setup, Firestore listeners
├── CLAUDE.md                   # View-Only architecture documentation
│
├── Shared/
│   ├── Domain/
│   │   ├── User.swift          # User model with SwiftData persistence
│   │   ├── Availability.swift  # WeeklySchedule, DaySchedule, TimeSlot, etc.
│   │   ├── Booking.swift       # Booking model with Firestore @DocumentID
│   │   ├── JournalEntry.swift  # Journal entry with mood tracking
│   │   ├── Payment.swift       # Payment model with status tracking
│   │   ├── SessionNote.swift   # Therapist session notes with hypotheses/observations
│   │   ├── ClientAnamnesis.swift  # Client history (background, issues, goals)
│   │   ├── Homework.swift      # Homework assignments with attachments
│   │   └── HomeworkResponse.swift  # Client responses to homework
│   │
│   ├── Data/
│   │   ├── AuthService.swift       # Google Sign-In via Firebase Auth + Calendar OAuth
│   │   ├── UserRepository.swift    # User state, auth, role assignment
│   │   ├── FirestoreService.swift  # Firestore CRUD operations
│   │   ├── AvailabilityRepository.swift  # Therapist availability with Firestore sync
│   │   ├── BookingRepository.swift       # Bookings with Firestore sync
│   │   ├── JournalRepository.swift       # Journal entries with Firestore sync
│   │   ├── JournalStorage.swift          # Local journal caching
│   │   ├── JournalPreferences.swift      # Privacy/biometric settings
│   │   ├── NotificationPreferences.swift # Push notification settings
│   │   ├── PrivacyPreferences.swift      # Crashlytics & privacy settings
│   │   ├── PaymentRepository.swift       # Monobank payment orchestration
│   │   ├── SessionNoteRepository.swift   # Session notes with Firestore sync
│   │   ├── SessionNoteStorage.swift      # Local session note caching
│   │   ├── HomeworkRepository.swift      # Homework with Firestore sync
│   │   ├── HomeworkStorage.swift         # Local homework caching
│   │   ├── StorageService.swift          # Firebase Cloud Storage for attachments
│   │   └── UserStorage.swift       # SwiftData local persistence
│   │
│   ├── Services/
│   │   ├── CalendarService.swift         # Calendar sync coordination
│   │   ├── GoogleCalendarService.swift   # Google Calendar API integration
│   │   ├── AppleCalendarService.swift    # EventKit integration
│   │   ├── MonobankService.swift         # Monobank API client
│   │   ├── BiometricService.swift        # Face ID / Touch ID
│   │   ├── AudioService.swift            # Voice message recording/playback
│   │   ├── PushNotificationService.swift # FCM push notifications
│   │   └── CrashlyticsService.swift      # Firebase Crashlytics management
│   │
│   └── UI/
│       ├── Design.swift        # Color palette, Spacing, CornerRadius
│       └── AdaptiveLayout.swift # iPad layout helpers (AdaptiveContainer, adaptiveReadableWidth)
│
├── Flows/
│   ├── AuthFlow/
│   │   └── Screens/
│   │       └── SignInScreen.swift  # Google Sign-In UI with custom logo
│   │
│   ├── ClientFlow/
│   │   ├── ClientFlow.swift    # Tab navigation for clients
│   │   └── Screens/
│   │       ├── BookingTab.swift        # Calendar + time slot selection
│   │       ├── HistoryTab.swift        # Booking history
│   │       ├── JournalTab.swift        # Journal entries list
│   │       ├── Journal/
│   │       │   ├── JournalEntryEditor.swift  # Create/edit entries
│   │       │   └── JournalEntryCard.swift    # Entry display component
│   │       ├── Homework/
│   │       │   ├── HomeworkTab.swift         # Homework list view
│   │       │   ├── ClientHomeworkCard.swift  # Homework display card
│   │       │   └── ClientHomeworkDetailSheet.swift  # View & respond to homework
│   │       └── ClientProfileTab.swift  # User profile + settings
│   │
│   ├── TherapistFlow/
│   │   ├── TherapistFlow.swift # Tab navigation for therapist
│   │   └── Screens/
│   │       ├── ScheduleTab.swift           # Dashboard + stats + schedule
│   │       ├── AvailabilitySettingsView.swift  # Configure working hours
│   │       ├── ClientsTab.swift            # Client list with session counts
│   │       ├── ClientDetail/
│   │       │   ├── ClientDetailScreen.swift    # Client profile + history
│   │       │   ├── ClientJournalSection.swift  # Shared journal entries
│   │       │   ├── ClientSessionNotesSection.swift  # Session notes list
│   │       │   ├── ClientAnamnesisSection.swift     # Client anamnesis display
│   │       │   ├── SessionNoteEditor.swift     # Rich-text session note editor
│   │       │   ├── SessionNoteCard.swift       # Session note display card
│   │       │   ├── AnamnesisEditor.swift       # Rich-text anamnesis editor
│   │       │   ├── ClientHomeworkSection.swift # Homework assignments section
│   │       │   ├── HomeworkCard.swift          # Homework display card
│   │       │   ├── HomeworkEditor.swift        # Create/edit homework
│   │       │   └── HomeworkDetailSheet.swift   # View homework + responses
│   │       ├── PaymentSettingsView.swift   # Monobank token & pricing config
│   │       └── TherapistProfileTab.swift   # Therapist profile + settings
│   │
│   └── Shared/
│       ├── CalendarSettingsView.swift      # Calendar sync toggle (therapist only)
│       ├── NotificationsSettingsView.swift # Push notification preferences
│       └── PrivacySettingsView.swift       # Privacy settings & account management
│
functions/                      # Firebase Cloud Functions
├── src/
│   └── index.ts               # Cloud Functions:
│                              #   - monobankWebhook: Payment confirmation
│                              #   - createCalendarEvent: Google Calendar + Meet
│                              #   - updateCalendarEvent: Reschedule/cancel sync
│                              #   - cleanupOldBookings: Scheduled cleanup
│                              #   - cleanupPendingBookings: Expire unpaid bookings
└── .env                       # Google OAuth credentials (not in git)
```

---

## 6. Design System

### Color Palette (Warm & Calming)

```swift
// Primary Colors
psyspacePrimary     = Color(red: 0.85, green: 0.65, blue: 0.40)  // Warm amber
psyspaceSecondary   = Color(red: 0.55, green: 0.65, blue: 0.55)  // Soft sage
psyspaceAccent      = Color(red: 0.78, green: 0.50, blue: 0.40)  // Terracotta

// Backgrounds
psyspaceBackground      = Color(red: 0.98, green: 0.97, blue: 0.95)  // Warm off-white
psyspaceBackgroundWarm  = Color(red: 0.99, green: 0.96, blue: 0.92)  // Cream
psyspaceCardBackground  = Color.white

// Text
psyspaceTextPrimary     = Color(red: 0.20, green: 0.18, blue: 0.16)  // Warm charcoal
psyspaceTextSecondary   = Color(red: 0.45, green: 0.42, blue: 0.40)  // Muted brown

// Decorative (for gradients & backgrounds)
psyspaceDecorative1     = Color(red: 0.95, green: 0.85, blue: 0.70).opacity(0.4)
psyspaceDecorative2     = Color(red: 0.75, green: 0.82, blue: 0.75).opacity(0.3)
psyspaceDecorative3     = Color(red: 0.90, green: 0.75, blue: 0.65).opacity(0.25)
```

### Spacing & Layout

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}
```

---

## 7. Security & Data Privacy

Mental health data requires careful handling:

1. **Google Authentication:** Secure OAuth 2.0 flow via Firebase Auth.
2. **Role-Based Access:** Email-based role assignment — only the configured therapist email gets elevated permissions.
3. **Server-Side Security:** Firestore Security Rules restrict data access based on authenticated user.
4. **Private vs. Shared Notes:** ✅ Clients explicitly choose which journal entries to share with the therapist.
5. **Biometric Protection:** ✅ Journal locked behind Face ID / Touch ID via LocalAuthentication framework.
6. **Data Deletion:** (Planned) Full data purge on account deletion request.

---

## 8. Development Roadmap

### ✅ Phase 1: Foundation (Complete)
- [x] Xcode project setup (SwiftUI, iOS 17.6+)
- [x] View-Only architecture with @Observable repositories
- [x] Firebase Firestore setup
- [x] Google Sign-In authentication
- [x] User model with SwiftData persistence
- [x] Role assignment by email
- [x] Stage/Flow/Screen navigation pattern
- [x] Design system (warm amber palette, spacing, typography)
- [x] Ukrainian localization

### ✅ Phase 2: Booking System (Complete)
- [x] Therapist availability management UI
- [x] Weekly schedule configuration (days, hours, session duration)
- [x] Client slot selection with calendar date picker
- [x] Real-time booking creation
- [x] Firestore sync between therapist and clients
- [x] Therapist dashboard with stats

### ✅ Phase 3: Monobank Payments (Complete)
- [x] Monobank API integration (MonobankService.swift)
- [x] Invoice generation flow (PaymentRepository, PaymentSheet)
- [x] Payment webhook handler (Cloud Function deployed)
- [x] Booking confirmation after successful payment
- [x] Cancellation and refund handling
- [x] Credit system for cancelled bookings (24h policy)
- [x] Test mode for development
- [x] Automated cleanup of old bookings (Cloud Function)

### ✅ Phase 4: Calendar Sync (Complete)
- [x] Google Calendar API integration (server-side Cloud Functions)
- [x] OAuth 2.0 token exchange for server-side access
- [x] Calendar event creation on booking with Google Meet link
- [x] Calendar event update on reschedule
- [x] Calendar event deletion on cancel
- [x] Email invites sent to both therapist and client
- [x] Optional sync toggle for therapist in settings

### ✅ Phase 5: Client Journal (Complete)
- [x] Rich-text journal editor with voice message support
- [x] Private / Shared note toggle
- [x] Biometric lock (Face ID / Touch ID)
- [x] Mood & emotion tracking (5-level scale)
- [x] Firebase Cloud Storage for audio files
- [x] Local caching with UserDefaults

### ✅ Phase 6: Therapist Tools (Complete)
- [x] Client list & profile view
- [x] View shared journal entries
- [x] Session notes per client (therapist's private notes)
- [x] Client anamnesis (background, presenting issues, goals)
- [x] Homework assignment feature (with attachments, responses, sharing)

### 🔲 Phase 7: Polish & Launch (In Progress)
- [x] iPad layout optimization (NavigationSplitView for both flows, adaptiveReadableWidth for detail screens)
- [x] Push notifications (FCM for cancellations/reschedules)
- [x] Payment settings screen
- [x] Calendar settings screen
- [x] Notifications settings screen (system status, booking/cancellation/reminder toggles)
- [x] Privacy settings screen (Crashlytics toggle, data storage info, account deletion)
- [x] Firebase Crashlytics integration (privacy-respecting, user-toggleable)
- [ ] Testing & bug fixes
- [ ] TestFlight beta release

---

## 9. Configuration Required

Before running the app, configure:

1. **Firebase:**
   - Add `GoogleService-Info.plist` to the project
   - Enable Firestore and Authentication in Firebase Console
   - Add Google Sign-In provider in Firebase Auth
   - Enable Cloud Functions and Cloud Messaging

2. **Google Sign-In:**
   - Add URL scheme from `GoogleService-Info.plist` (`REVERSED_CLIENT_ID`)
   - Configure in Xcode: Target → Info → URL Types

3. **Google Calendar API:**
   - Enable Google Calendar API in Google Cloud Console
   - Create Web OAuth 2.0 credentials (for server-side access)
   - Add Web Client ID and Secret to `functions/.env`

4. **Monobank:**
   - Get merchant token from Monobank Acquiring
   - Configure webhook URL to Cloud Function endpoint

5. **Cloud Functions:**
   - Deploy functions: `firebase deploy --only functions`
   - Set environment variables in `functions/.env`:
     ```
     GOOGLE_CLIENT_ID=<web-client-id>
     GOOGLE_CLIENT_SECRET=<web-client-secret>
     ```

6. **Firestore Collections:**
   - `users` (user profiles, credits, and settings)
   - `availability` (single document for therapist settings)
   - `bookings` (confirmed bookings with status tracking)
   - `pendingBookings` (unpaid booking holds)
   - `journalEntries` (client journal entries with sharing flags)
   - `sessionNotes` (therapist session notes per client)
   - `clientAnamnesis` (client background and treatment goals)
   - `homework` (therapist homework assignments with attachments)
   - `homeworkResponses` (client responses with completion and sharing flags)
   - `config/therapist` (calendar OAuth tokens)
