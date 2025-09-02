//
//  MailTransportCoordinator.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Coordinatore per il layer di trasporto email
//  Gestisce i diversi provider e instrada le richieste
//

import Foundation
import Combine

/// Coordinatore principale per il trasporto email
public final class MailTransportCoordinator {

    // MARK: - Properties

    private var providers: [MailProviderType: MailProvider] = [:]
    private let queue = DispatchQueue(label: "com.marilena.mail.transport", qos: .userInitiated)

    // MARK: - Initialization

    public init() {
        setupDefaultProviders()
    }

    // MARK: - Provider Management

    /// Registra un provider per un tipo specifico
    public func registerProvider(_ provider: MailProvider, for type: MailProviderType) {
        queue.sync {
            providers[type] = provider
        }
    }

    /// Rimuove un provider
    public func unregisterProvider(for type: MailProviderType) {
        queue.sync {
            providers[type] = nil
        }
    }

    /// Ottiene il provider per un tipo specifico
    public func provider(for type: MailProviderType) -> MailProvider? {
        queue.sync {
            providers[type]
        }
    }

    /// Lista di tutti i provider registrati
    public var availableProviders: [MailProvider] {
        queue.sync {
            Array(providers.values)
        }
    }

    // MARK: - Transport Operations

    /// Connette un account usando il provider appropriato
    public func connectAccount(_ account: MailAccount) -> AnyPublisher<MailConnectionResult, MailProviderError> {
        guard let provider = provider(for: account.provider) else {
            return Fail(error: .invalidRequest("Provider \(account.provider.rawValue) non disponibile"))
                .eraseToAnyPublisher()
        }

        return provider.connect(with: account)
            .handleEvents(receiveOutput: { [weak self] result in
                if case .success = result {
                    self?.registerProvider(provider, for: account.provider)
                }
            })
            .eraseToAnyPublisher()
    }

    /// Sincronizza email per un account
    public func syncEmails(for account: MailAccount, options: MailSyncOptions = .init()) -> AnyPublisher<MailSyncUpdate, MailProviderError> {
        guard let provider = provider(for: account.provider) else {
            return Fail(error: .notConnected)
                .eraseToAnyPublisher()
        }

        return provider.syncEmails(options: options)
    }

    /// Invia email usando il provider appropriato
    public func sendEmail(_ message: MailMessage, using account: MailAccount) -> AnyPublisher<MailSendResult, MailProviderError> {
        guard let provider = provider(for: account.provider) else {
            return Fail(error: .notConnected)
                .eraseToAnyPublisher()
        }

        return provider.sendEmail(message)
    }

    // MARK: - Private Methods

    private func setupDefaultProviders() {
        // Questi saranno implementati nei file successivi
        // registerProvider(GmailProvider(), for: .gmail)
        // registerProvider(MicrosoftProvider(), for: .microsoft)
        // registerProvider(IMAPProvider(), for: .imap)
    }
}

// MARK: - Provider Factory

public extension MailTransportCoordinator {

    /// Crea un provider per un tipo specifico
    static func createProvider(for type: MailProviderType) -> MailProvider? {
        switch type {
        case .gmail:
            return GmailMailProvider()
        case .microsoft:
            return MicrosoftMailProvider()
        case .imap:
            return IMAPMailProvider()
        }
    }
}
