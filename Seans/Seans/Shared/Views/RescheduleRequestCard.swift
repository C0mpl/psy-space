//
//  RescheduleRequestCard.swift
//  Seans
//
//  Created by Claude on 25.08.2026.
//

import SwiftUI

struct RescheduleRequestCard: View {
    @Environment(BookingRepository.self) private var bookingRepo

    let booking: Booking
    let isCurrentUserRequester: Bool

    @State private var isApproving = false
    @State private var isRejecting = false
    @State private var showingError = false

    private var request: RescheduleRequest? {
        booking.rescheduleRequest
    }

    var body: some View {
        if let request {
            VStack(alignment: .leading, spacing: Spacing.md) {
                headerSection(request: request)

                Divider()

                timeComparisonSection(request: request)

                if !isCurrentUserRequester {
                    actionButtons
                } else {
                    awaitingResponseSection
                }
            }
            .padding(Spacing.md)
            .background(Color.seansWarning.opacity(0.1))
            .clipShape(.rect(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.seansWarning.opacity(0.3), lineWidth: 1)
            )
            .alert("Помилка", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Не вдалося обробити запит. Спробуйте ще раз.")
            }
        }
    }

    // MARK: - Sections

    private func headerSection(request: RescheduleRequest) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Color.seansWarning)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Запит на перенесення")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)

                Text(requestedByText(request: request))
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            }

            Spacer()
        }
    }

    private func timeComparisonSection(request: RescheduleRequest) -> some View {
        HStack(spacing: Spacing.md) {
            // Current time
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Зараз")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)

                Text(booking.dateFormatted)
                    .font(.subheadline)
                    .foregroundStyle(Color.seansTextPrimary)

                Text(booking.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(Color.seansWarning)
                .font(.title3)

            // New time
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Новий час")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)

                Text(request.newDateFormatted)
                    .font(.subheadline)
                    .foregroundStyle(Color.seansPrimary)

                Text(request.newTimeFormatted)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansPrimary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                rejectRequest()
            } label: {
                HStack {
                    if isRejecting {
                        ProgressView()
                            .tint(Color.seansError)
                    } else {
                        Text("Відхилити")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeansSecondaryButtonStyle())
            .disabled(isApproving || isRejecting)
            .accessibilityLabel("Відхилити запит на перенесення")

            Button {
                approveRequest()
            } label: {
                HStack {
                    if isApproving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Підтвердити")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeansPrimaryButtonStyle(isLoading: isApproving))
            .disabled(isApproving || isRejecting)
            .accessibilityLabel("Підтвердити перенесення сеансу")
        }
    }

    private var awaitingResponseSection: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Очікуємо відповіді...")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)

            Spacer()

            Button("Скасувати") {
                cancelRequest()
            }
            .font(.subheadline)
            .foregroundStyle(Color.seansError)
            .disabled(isRejecting)
        }
    }

    // MARK: - Helpers

    private func requestedByText(request: RescheduleRequest) -> String {
        let requester = request.requestedBy == .therapist ? "Терапевт" : "Клієнт"
        let timeAgo = request.requestedAt.formatted(.relative(presentation: .named))
        return "\(requester) надіслав \(timeAgo)"
    }

    // MARK: - Actions

    private func approveRequest() {
        isApproving = true

        Task {
            do {
                try await bookingRepo.approveReschedule(booking.bookingId)
                HapticService.notification(.success)
            } catch {
                HapticService.notification(.error)
                showingError = true
            }
            isApproving = false
        }
    }

    private func rejectRequest() {
        isRejecting = true

        Task {
            await bookingRepo.rejectReschedule(booking.bookingId)
            HapticService.notification(.warning)
            isRejecting = false
        }
    }

    private func cancelRequest() {
        isRejecting = true

        Task {
            await bookingRepo.cancelRescheduleRequest(booking.bookingId)
            HapticService.notification(.warning)
            isRejecting = false
        }
    }
}

#Preview("Pending - For Approver") {
    RescheduleRequestCard(
        booking: Booking(
            clientId: "1",
            clientName: "Тест",
            date: .now.addingTimeInterval(86400 * 3),
            startTime: .now.addingTimeInterval(86400 * 3),
            endTime: .now.addingTimeInterval(86400 * 3 + 3600),
            rescheduleRequest: RescheduleRequest(
                requestedBy: .client,
                requestedAt: .now.addingTimeInterval(-3600),
                newDate: .now.addingTimeInterval(86400 * 5),
                newStartTime: .now.addingTimeInterval(86400 * 5),
                newEndTime: .now.addingTimeInterval(86400 * 5 + 3600),
                status: .pending
            )
        ),
        isCurrentUserRequester: false
    )
    .environment(BookingRepository())
    .padding()
}

#Preview("Pending - For Requester") {
    RescheduleRequestCard(
        booking: Booking(
            clientId: "1",
            clientName: "Тест",
            date: .now.addingTimeInterval(86400 * 3),
            startTime: .now.addingTimeInterval(86400 * 3),
            endTime: .now.addingTimeInterval(86400 * 3 + 3600),
            rescheduleRequest: RescheduleRequest(
                requestedBy: .client,
                requestedAt: .now.addingTimeInterval(-3600),
                newDate: .now.addingTimeInterval(86400 * 5),
                newStartTime: .now.addingTimeInterval(86400 * 5),
                newEndTime: .now.addingTimeInterval(86400 * 5 + 3600),
                status: .pending
            )
        ),
        isCurrentUserRequester: true
    )
    .environment(BookingRepository())
    .padding()
}
