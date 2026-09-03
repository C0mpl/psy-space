//
//  ClientSessionNotesSection.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct ClientSessionNotesSection: View {
    let clientId: String
    let clientName: String

    @Environment(BookingRepository.self) private var bookingRepo
    @State private var noteRepo = SessionNoteRepository()
    @State private var selectedBookingId: String?
    @State private var selectedNoteId: String?

    private var completedSessions: [Booking] {
        let now = Date.now
        return bookingRepo.bookings
            .filter { booking in
                booking.clientId == clientId &&
                booking.status != .cancelled &&
                (booking.status == .completed || booking.endTime < now)
            }
            .sorted { $0.startTime > $1.startTime }
    }

    private var selectedBooking: Booking? {
        guard let id = selectedBookingId else { return nil }
        return completedSessions.first { $0.bookingId == id }
    }

    private var selectedNote: SessionNote? {
        guard let id = selectedNoteId else { return nil }
        return noteRepo.notes.first { $0.noteId == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader

            if completedSessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .onAppear {
            noteRepo.startListening(forClientId: clientId)
        }
        .onDisappear {
            noteRepo.stopListening()
        }
        .sheet(isPresented: Binding(
            get: { selectedBookingId != nil },
            set: { if !$0 { selectedBookingId = nil } }
        )) {
            if let booking = selectedBooking {
                SessionNoteEditor(
                    bookingId: booking.bookingId,
                    clientId: clientId,
                    sessionDate: booking.startTime,
                    existingNote: noteRepo.note(forBookingId: booking.bookingId)
                )
                .environment(noteRepo)
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedNoteId != nil },
            set: { if !$0 { selectedNoteId = nil } }
        )) {
            if let note = selectedNote,
               let booking = completedSessions.first(where: { $0.bookingId == note.bookingId }) {
                SessionNoteEditor(
                    bookingId: note.bookingId,
                    clientId: clientId,
                    sessionDate: booking.startTime,
                    existingNote: note
                )
                .environment(noteRepo)
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Label("Нотатки до сеансів", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            Spacer()

            let notesCount = noteRepo.notes.count
            let sessionsCount = completedSessions.count
            Text("\(notesCount)/\(sessionsCount)")
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 32))
                .foregroundStyle(Color.seansTextSecondary.opacity(0.5))

            Text("Немає завершених сеансів")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)

            Text("Нотатки можна додавати після завершення сеансу")
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    private var sessionsList: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(completedSessions) { booking in
                if let note = noteRepo.note(forBookingId: booking.bookingId) {
                    SessionNoteCard(
                        note: note,
                        sessionDate: booking.startTime
                    ) {
                        selectedNoteId = note.noteId
                    }
                } else {
                    SessionWithoutNoteCard(booking: booking) {
                        selectedBookingId = booking.bookingId
                    }
                }
            }
        }
    }
}

#Preview {
    ClientSessionNotesSection(clientId: "test-client", clientName: "Іван Петренко")
        .environment(BookingRepository())
        .padding()
        .background(Color.seansBackground)
}
