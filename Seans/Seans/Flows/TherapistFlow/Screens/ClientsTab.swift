//
//  ClientsTab.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct ClientsTab: View {
    @Environment(BookingRepository.self) private var bookingRepo
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedClient: ClientInfo?

    private var clients: [ClientInfo] {
        let allBookings = bookingRepo.bookings
        var clientDict: [String: ClientInfo] = [:]
        let now = Date.now

        for booking in allBookings {
            // Skip cancelled bookings entirely
            if booking.status == .cancelled {
                continue
            }

            let isCompleted = booking.status == .completed || (booking.status == .confirmed && booking.endTime < now)
            let isUpcoming = booking.status == .confirmed && booking.startTime > now

            if clientDict[booking.clientId] == nil {
                clientDict[booking.clientId] = ClientInfo(
                    id: booking.clientId,
                    name: booking.clientName,
                    email: booking.clientEmail,
                    nextSessionDate: isUpcoming ? booking.date : nil,
                    lastCompletedDate: isCompleted ? booking.date : nil,
                    completedSessions: isCompleted ? 1 : 0
                )
            } else {
                if isCompleted {
                    clientDict[booking.clientId]?.completedSessions += 1
                    if booking.date > (clientDict[booking.clientId]?.lastCompletedDate ?? .distantPast) {
                        clientDict[booking.clientId]?.lastCompletedDate = booking.date
                    }
                }
                if isUpcoming {
                    let currentNext = clientDict[booking.clientId]?.nextSessionDate
                    if booking.date < (currentNext ?? .distantFuture) {
                        clientDict[booking.clientId]?.nextSessionDate = booking.date
                    }
                }
            }
        }

        return clientDict.values.sorted { $0.name < $1.name }
    }

    var body: some View {
        AdaptiveContainer {
            compactLayout
        } regular: {
            regularLayout
        }
    }

    // MARK: - iPhone Layout (NavigationStack)

    private var compactLayout: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    emptyState
                } else {
                    clientsList
                }
            }
            .background(Color.seansBackground)
            .navigationTitle("Клієнти")
            .navigationDestination(for: ClientInfo.self) { client in
                ClientDetailScreen(clientId: client.id, clientName: client.name)
            }
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var regularLayout: some View {
        NavigationSplitView {
            Group {
                if clients.isEmpty {
                    emptyState
                } else {
                    clientsListForSplit
                }
            }
            .background(Color.seansBackground)
            .navigationTitle("Клієнти")
        } detail: {
            if let client = selectedClient {
                ClientDetailScreen(clientId: client.id, clientName: client.name)
            } else {
                noClientSelectedView
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var clientsListForSplit: some View {
        List(clients, selection: $selectedClient) { client in
            ClientRow(client: client)
                .tag(client)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var noClientSelectedView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(Color.seansTextSecondary)

            Text("Оберіть клієнта")
                .font(.title3)
                .foregroundStyle(Color.seansTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.seansBackground)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer(minLength: Spacing.xxl)

                ZStack {
                    Circle()
                        .fill(Color.seansAccent.opacity(0.1))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.seansAccent.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.seansAccent)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Поки немає клієнтів")
                        .font(.title2.bold())
                        .foregroundStyle(Color.seansTextPrimary)

                    Text("Клієнти з'являться тут після\nпершого запису на сеанс")
                        .font(.body)
                        .foregroundStyle(Color.seansTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer(minLength: Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var clientsList: some View {
        List {
            ForEach(clients) { client in
                NavigationLink(value: client) {
                    ClientRow(client: client)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct ClientRow: View {
    let client: ClientInfo

    private var sessionCountText: String {
        let count = client.completedSessions
        if count == 0 {
            return "Ще не було сеансів"
        } else if count == 1 {
            return "1 сеанс"
        } else if count < 5 {
            return "\(count) сеанси"
        } else {
            return "\(count) сеансів"
        }
    }

    private var dateText: String? {
        if let next = client.nextSessionDate {
            return "Наступний: \(next.formatted(date: .abbreviated, time: .omitted))"
        } else if let last = client.lastCompletedDate {
            return "Останній: \(last.formatted(date: .abbreviated, time: .omitted))"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.seansPrimary.opacity(0.1))
                    .frame(width: 50, height: 50)

                Text(client.name.prefix(1).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(Color.seansPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(client.name)
                    .font(.headline)
                    .foregroundStyle(Color.seansTextPrimary)

                HStack(spacing: Spacing.xs) {
                    Text(sessionCountText)

                    if let dateText {
                        Text("•")
                        Text(dateText)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}

struct ClientInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String?
    var nextSessionDate: Date?
    var lastCompletedDate: Date?
    var completedSessions: Int
}

#Preview {
    ClientsTab()
        .environment(BookingRepository())
}
