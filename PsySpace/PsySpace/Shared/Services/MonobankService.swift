//
//  MonobankService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 25.08.2026.
//

import Foundation

actor MonobankService {
    static let shared = MonobankService()

    private let baseURL = URL(string: "https://api.monobank.ua/api/merchant")!
    private let urlSession: URLSession
    private let redirectScheme = "psyspace"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        urlSession = URLSession(configuration: config)
    }

    struct CreateInvoiceRequest: Encodable {
        let amount: Int
        let merchantPaymInfo: MerchantPaymInfo
        let redirectUrl: String
        let webHookUrl: String?
        let validity: Int

        struct MerchantPaymInfo: Encodable {
            let reference: String
            let destination: String
        }
    }

    struct CreateInvoiceResponse: Decodable {
        let invoiceId: String
        let pageUrl: String
    }

    func createInvoice(
        amount: Int,
        reference: String,
        description: String,
        webhookUrl: String?,
        token: String
    ) async throws(PaymentError) -> (invoiceId: String, pageUrl: String) {
        let endpoint = baseURL.appendingPathComponent("invoice/create")

        let body = CreateInvoiceRequest(
            amount: amount,
            merchantPaymInfo: .init(reference: reference, destination: description),
            redirectUrl: "\(redirectScheme)://payment-callback?reference=\(reference)",
            webHookUrl: webhookUrl,
            validity: 3600
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Token")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .invalidResponse
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaymentError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = Self.parseErrorResponse(from: data) ?? "HTTP \(httpResponse.statusCode)"
                throw PaymentError.apiError(errorMessage)
            }

            let invoiceResponse = try JSONDecoder().decode(CreateInvoiceResponse.self, from: data)
            return (invoiceResponse.invoiceId, invoiceResponse.pageUrl)
        } catch let paymentError as PaymentError {
            throw paymentError
        } catch {
            throw .networkError(error)
        }
    }

    struct InvoiceStatusResponse: Decodable {
        let invoiceId: String
        let status: String
        let amount: Int?
        let finalAmount: Int?
        let reference: String?
        let failureReason: String?
    }

    func checkStatus(invoiceId: String, token: String) async throws(PaymentError) -> PaymentStatus {
        var components = URLComponents(url: baseURL.appendingPathComponent("invoice/status"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "invoiceId", value: invoiceId)]

        guard let endpoint = components.url else {
            throw .invalidResponse
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Token")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaymentError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = Self.parseErrorResponse(from: data) ?? "HTTP \(httpResponse.statusCode)"
                throw PaymentError.apiError(errorMessage)
            }

            let statusResponse = try JSONDecoder().decode(InvoiceStatusResponse.self, from: data)
            return mapStatus(statusResponse.status)
        } catch let paymentError as PaymentError {
            throw paymentError
        } catch {
            throw .networkError(error)
        }
    }

    private func mapStatus(_ status: String) -> PaymentStatus {
        switch status.lowercased() {
        case "created", "processing":
            return .processing
        case "hold", "success":
            return .success
        case "failure":
            return .failure
        case "reversed":
            return .refunded
        case "expired":
            return .expired
        default:
            return .pending
        }
    }

    struct CancelInvoiceRequest: Encodable {
        let invoiceId: String
        let extRef: String?
        let amount: Int?
    }

    struct CancelInvoiceResponse: Decodable {
        let status: String
    }

    func cancelInvoice(
        invoiceId: String,
        reference: String?,
        amount: Int?,
        token: String
    ) async throws(PaymentError) -> Bool {
        let endpoint = baseURL.appendingPathComponent("invoice/cancel")

        let body = CancelInvoiceRequest(
            invoiceId: invoiceId,
            extRef: reference,
            amount: amount
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Token")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .invalidResponse
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaymentError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = Self.parseErrorResponse(from: data) ?? "HTTP \(httpResponse.statusCode)"
                throw PaymentError.apiError(errorMessage)
            }

            let cancelResponse = try JSONDecoder().decode(CancelInvoiceResponse.self, from: data)
            let status = cancelResponse.status.lowercased()

            return status == "reversed" || status == "processing" || status == "success"
        } catch let paymentError as PaymentError {
            throw paymentError
        } catch {
            throw .networkError(error)
        }
    }

    private nonisolated static func parseErrorResponse(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(MonobankErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.errText
    }
}

private struct MonobankErrorResponse: Decodable, Sendable {
    let errCode: String?
    let errText: String?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        errCode = try container.decodeIfPresent(String.self, forKey: .errCode)
        errText = try container.decodeIfPresent(String.self, forKey: .errText)
    }

    private enum CodingKeys: String, CodingKey {
        case errCode
        case errText
    }
}
