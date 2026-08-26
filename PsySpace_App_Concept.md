# Seans — Pet Project Concept & Architecture Breakdown

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
| **Calendar Sync** | Optional sync of booked sessions to Apple Calendar (EventKit) or Google Calendar. | 🔲 Pending |
| **Therapeutic Journal & Notes** | Private rich-text diary for thoughts, breakthroughs, and session prep notes. | 🔲 Pending |
| **Mood & Emotion Tracker** | Daily emotional state check-in using a structured scale (e.g., Plutchik's Wheel of Emotions). | 🔲 Pending |
| **Contextual Note Sharing** | Option to attach specific journal entries to an upcoming session for therapist review. | 🔲 Pending |
| **Privacy & Security** | Biometric lock (Face ID / Touch ID / PIN) + option to mark notes as strictly private. | 🔲 Pending |

### 2.2. Therapist Features (Same App, Elevated Role)

| Feature | Description | Status |
| :--- | :--- | :--- |
| **Availability Management** | Set working days, hours, session duration, and breaks directly in the app. | ✅ Implemented |
| **Real-time Booking Sync** | All bookings sync instantly via Firebase Firestore between therapist and clients. | ✅ Implemented |
| **Dashboard Stats** | View today's session count, upcoming sessions, and weekly schedule overview. | ✅ Implemented |
| **Calendar Sync** | Push booked sessions to Apple Calendar (EventKit) or Google Calendar. | 🔲 Pending |
| **Client Management** | View client profiles, session history, and shared notes. | 🔲 Pending |
| **Session Notes & Anamnesis** | Record session notes, hypotheses, and treatment observations per client. | 🔲 Pending |
| **Cancellation Policies** | Configurable cancellation windows (e.g., free up to 24h; partial/full retention after). | ✅ Implemented |
| **Homework & Materials** | Assign exercises (CBT worksheets, reading materials) to clients. | 🔲 Pending |

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
* **Google Sign-In SDK:** OAuth 2.0 authentication flow
* **Firebase Firestore:** Real-time NoSQL database
* **Monobank API:** Invoice generation (`/merchant/invoice/create`), webhook handler for payment status. (Pending)
* **Apple Calendar:** EventKit framework — direct on-device calendar access. (Pending)
* **Google Calendar:** Google Calendar API with OAuth 2.0. (Pending)
* **Notifications:** Apple Push Notification service (APNs), optionally via Firebase Cloud Messaging. (Pending)

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
              │  └─────────────────────┘  │
              └───────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────┐
              │     Firebase Auth         │
              │    (Google Sign-In)       │
              └───────────────────────────┘
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

### Future: Monobank Payment & Booking Workflow

1. **Selection:** Client picks an open time slot from therapist's availability.
2. **Reservation:** The slot is temporarily locked for 15 minutes.
3. **Invoice Creation:** Backend calls Monobank API to generate a payment invoice.
4. **Payment Execution:** Client pays via MonoPay (Apple Pay / card).
5. **Webhook Verification:** Monobank sends webhook to backend confirming payment.
6. **Confirmation:**
   * Slot is permanently booked in the database.
   * Push notification sent to both client and therapist.
   * Optional: Calendar event created via EventKit or Google Calendar API.

---

## 5. Project Structure

```
Seans/
├── SeansApp.swift              # App entry point, Firebase init, Google Sign-In URL handling
├── Stage.swift                 # Flow orchestrator, repository setup, Firestore listeners
├── CLAUDE.md                   # View-Only architecture documentation
│
├── Shared/
│   ├── Domain/
│   │   ├── User.swift          # User model with SwiftData persistence
│   │   ├── Availability.swift  # WeeklySchedule, DaySchedule, TimeSlot, etc.
│   │   └── Booking.swift       # Booking model with Firestore @DocumentID
│   │
│   ├── Data/
│   │   ├── AuthService.swift       # Google Sign-In via Firebase Auth
│   │   ├── UserRepository.swift    # User state, auth, role assignment
│   │   ├── FirestoreService.swift  # Firestore CRUD operations
│   │   ├── AvailabilityRepository.swift  # Therapist availability with Firestore sync
│   │   ├── BookingRepository.swift       # Bookings with Firestore sync
│   │   └── UserStorage.swift       # SwiftData local persistence
│   │
│   └── UI/
│       └── Design.swift        # Color palette, Spacing, CornerRadius
│
├── Flows/
│   ├── AuthFlow/
│   │   └── Screens/
│   │       └── SignInScreen.swift  # Google Sign-In UI with custom logo
│   │
│   ├── ClientFlow/
│   │   ├── ClientFlow.swift    # Tab navigation for clients
│   │   └── Screens/
│   │       ├── BookingTab.swift    # Calendar + time slot selection
│   │       ├── HistoryTab.swift    # Booking history (placeholder)
│   │       └── ProfileTab.swift    # User profile (placeholder)
│   │
│   └── TherapistFlow/
│       ├── TherapistFlow.swift # Tab navigation for therapist
│       └── Screens/
│           ├── ScheduleTab.swift           # Dashboard + stats + schedule
│           ├── AvailabilitySettingsView.swift  # Configure working hours
│           ├── ClientsTab.swift            # Client list (placeholder)
│           └── ProfileTab.swift            # Therapist profile (placeholder)
```

---

## 6. Design System

### Color Palette (Warm & Calming)

```swift
// Primary Colors
seansPrimary     = Color(red: 0.85, green: 0.65, blue: 0.40)  // Warm amber
seansSecondary   = Color(red: 0.55, green: 0.65, blue: 0.55)  // Soft sage
seansAccent      = Color(red: 0.78, green: 0.50, blue: 0.40)  // Terracotta

// Backgrounds
seansBackground      = Color(red: 0.98, green: 0.97, blue: 0.95)  // Warm off-white
seansBackgroundWarm  = Color(red: 0.99, green: 0.96, blue: 0.92)  // Cream
seansCardBackground  = Color.white

// Text
seansTextPrimary     = Color(red: 0.20, green: 0.18, blue: 0.16)  // Warm charcoal
seansTextSecondary   = Color(red: 0.45, green: 0.42, blue: 0.40)  // Muted brown

// Decorative (for gradients & backgrounds)
seansDecorative1     = Color(red: 0.95, green: 0.85, blue: 0.70).opacity(0.4)
seansDecorative2     = Color(red: 0.75, green: 0.82, blue: 0.75).opacity(0.3)
seansDecorative3     = Color(red: 0.90, green: 0.75, blue: 0.65).opacity(0.25)
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
4. **Private vs. Shared Notes:** (Planned) Clients explicitly choose which journal entries to share with the therapist.
5. **Biometric & PIN Protection:** (Planned) App locked behind Face ID / Touch ID / PIN.
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

### 🔲 Phase 4: Calendar Sync (Pending)
- [ ] EventKit integration (Apple Calendar)
- [ ] Google Calendar API integration
- [ ] Optional sync toggle per user
- [ ] Calendar event creation on booking

### 🔲 Phase 5: Client Journal (Pending)
- [ ] Rich-text journal editor
- [ ] Private / Shared note toggle
- [ ] Biometric lock (Face ID / PIN)
- [ ] Mood & emotion tracking

### 🔲 Phase 6: Therapist Tools (Pending)
- [ ] Client list & profile view
- [ ] Session notes per client
- [ ] View shared journal entries
- [ ] Homework assignment feature

### 🔲 Phase 7: Polish & Launch (Pending)
- [ ] iPad layout optimization
- [ ] Push notifications (APNs)
- [ ] Testing & bug fixes
- [ ] TestFlight beta release

---

## 9. Configuration Required

Before running the app, configure:

1. **Firebase:**
   - Add `GoogleService-Info.plist` to the project
   - Enable Firestore and Authentication in Firebase Console
   - Add Google Sign-In provider in Firebase Auth

2. **Google Sign-In:**
   - Add URL scheme from `GoogleService-Info.plist` (`REVERSED_CLIENT_ID`)
   - Configure in Xcode: Target → Info → URL Types

3. **Therapist Email:**
   - Update `therapistEmail` in `UserRepository.swift` with the actual therapist's email

4. **Firestore Collections:**
   - `availability` (single document for therapist settings)
   - `bookings` (collection of booking documents)
