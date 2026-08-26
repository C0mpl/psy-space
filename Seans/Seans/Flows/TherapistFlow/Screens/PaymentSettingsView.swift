//
//  PaymentSettingsView.swift
//  Seans
//
//  Created by Claude on 25.08.2026.
//

import SwiftUI

struct PaymentSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AvailabilityRepository.self) private var availabilityRepo

    @State private var merchantToken = ""
    @State private var webhookUrl = ""
    @State private var isTokenVisible = false
    @State private var isTestMode = false
    @State private var showingSaveConfirmation = false
    @State private var isSaving = false

    private let remoteConfig = RemoteConfigService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    priceRow
                } header: {
                    Text("Ціна")
                } footer: {
                    Text("Ця сума буде списана з клієнта при бронюванні сеансу.")
                }

                Section {
                    testModeRow
                } header: {
                    Text("Режим тестування")
                } footer: {
                    Text(isTestMode
                         ? "Тестовий режим увімкнено. Реальні платежі не обробляються — клієнт побачить кнопки симуляції оплати."
                         : "Увімкніть для тестування без реальних транзакцій.")
                }

                Section {
                    tokenRow
                } header: {
                    Text("Monobank Еквайринг")
                } footer: {
                    Text(isTestMode
                         ? "В тестовому режимі токен не потрібен."
                         : "Токен доступу до Monobank Acquiring API. Отримайте його в бізнес-акаунті Monobank.")
                }

                Section {
                    webhookRow
                } header: {
                    Text("Webhook URL")
                } footer: {
                    Text("URL вашої Firebase Cloud Function для обробки платежів. Формат: https://us-central1-PROJECT.cloudfunctions.net/monobankWebhook")
                }

                Section {
                    Button {
                        saveSettings()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Зберегти")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(SeansPrimaryButtonStyle(isLoading: isSaving))
                    .disabled((!isTestMode && merchantToken.isEmpty) || isSaving)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    Link(destination: URL(string: "https://api.monobank.ua/docs/acquiring.html")!) {
                        Label("Документація Monobank API", systemImage: "book")
                    }
                } header: {
                    Text("Довідка")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.seansBackground)
            .navigationTitle("Оплата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") {
                        dismiss()
                    }
                }
            }
            .alert("Збережено", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Налаштування оплати збережено успішно.")
            }
            .task {
                await loadSettings()
            }
        }
    }

    // MARK: - Rows

    private var testModeRow: some View {
        Toggle(isOn: $isTestMode) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(isTestMode ? Color.seansWarning : Color.seansTextSecondary)
                Text("Тестовий режим")
            }
        }
        .tint(Color.seansWarning)
    }

    @MainActor
    private var priceRow: some View {
        @Bindable var repo = availabilityRepo
        return HStack {
            Text("Ціна сеансу")
            Spacer()
            TextField("", value: Binding(
                get: { availabilityRepo.settings.sessionPriceUAH },
                set: { availabilityRepo.updateSessionPrice($0) }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            Text("\u{20B4}")
                .foregroundStyle(Color.seansTextSecondary)
        }
    }

    private var tokenRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                if isTokenVisible {
                    TextField("Введіть токен", text: $merchantToken)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("Введіть токен", text: $merchantToken)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Button {
                    isTokenVisible.toggle()
                } label: {
                    Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                        .foregroundStyle(Color.seansTextSecondary)
                }
                .buttonStyle(.plain)
            }

            if !merchantToken.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.seansSuccess)
                        .font(.caption)
                    Text("Токен налаштовано")
                        .font(.caption)
                        .foregroundStyle(Color.seansSuccess)
                }
            }
        }
    }

    private var webhookRow: some View {
        TextField("https://...", text: $webhookUrl)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
    }

    // MARK: - Actions

    private func loadSettings() async {
        isTestMode = await remoteConfig.isTestMode
        if let token = await remoteConfig.monobankMerchantToken {
            merchantToken = token
        }
        if let url = await remoteConfig.monobankWebhookUrl {
            webhookUrl = url
        }
    }

    private func saveSettings() {
        isSaving = true

        Task {
            await remoteConfig.setTestMode(isTestMode)

            if !isTestMode {
                await remoteConfig.setMonobankMerchantToken(merchantToken)
                if !webhookUrl.isEmpty {
                    await remoteConfig.setMonobankWebhookUrl(webhookUrl)
                }
            }

            await MainActor.run {
                isSaving = false
                showingSaveConfirmation = true
            }
        }
    }
}

#Preview {
    PaymentSettingsView()
        .environment(AvailabilityRepository())
}
