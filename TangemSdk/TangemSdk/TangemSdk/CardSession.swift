//
//  CardSession.swift
//  TangemSdk
//
//  Created by Alexander Osokin on 18.03.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import Combine

public typealias CompletionResult<T> = (Result<T, SessionError>) -> Void

/// Base protocol for run tasks in a card session
@available(iOS 13.0, *)
public protocol CardSessionRunnable {
    
    /// Simple interface for responses received after sending commands to Tangem cards.
    associatedtype CommandResponse: TlvCodable
    
    /// The starting point for custom business logic. Adopt this protocol and use `TangemSdk.startSession` to run
    /// - Parameters:
    ///   - session: You can run commands in this session
    ///   - completion: Call the completion handler to complete the task.
    func run(in session: CardSession, completion: @escaping CompletionResult<CommandResponse>)
}

/// Allows interaction with Tangem cards. Should be open before sending commands
@available(iOS 13.0, *)
public class CardSession {
    /// Allows interaction with users and shows visual elements.
    public let viewDelegate: SessionViewDelegate
    
    /// Contains data relating to the current Tangem card. It is used in constructing all the commands,
    /// and commands can modify `SessionEnvironment`.
    public private(set) var environment: SessionEnvironment
    
    /// True when some operation is still in progress.
    public private(set) var isBusy = false
    
    private let reader: CardReader
    private let semaphore = DispatchSemaphore(value: 1)
    private let initialMessage: String?
    private let cardId: String?
    private var sendSubscription: [AnyCancellable] = []
    private var connectedTagSubscription: [AnyCancellable] = []
    
    /// Main initializer
    /// - Parameters:
    ///   - environment: Contains data relating to a Tangem card
    ///   - cardId: CID, Unique Tangem card ID number. If not nil, the SDK will check that you tapped the  card with this cardID and will return the `wrongCard` error' otherwise
    ///   - initialMessage: A custom description that shows at the beginning of the NFC session. If nil, default message will be used
    ///   - cardReader: NFC-reader implementation
    ///   - viewDelegate: viewDelegate implementation
    public init(environment: SessionEnvironment, cardId: String? = nil, initialMessage: String? = nil, cardReader: CardReader, viewDelegate: SessionViewDelegate) {
        self.reader = cardReader
        self.viewDelegate = viewDelegate
        self.environment = environment
        self.initialMessage = initialMessage
        self.cardId = cardId
    }
    
    deinit {
        print ("Card session deinit")
    }
    
    /// This metod starts a card session, performs preflight `Read` command,  invokes the `run ` method of `CardSessionRunnable` and closes the session.
    /// - Parameters:
    ///   - runnable: The CardSessionRunnable implemetation
    ///   - completion: Completion handler. `(Swift.Result<CardSessionRunnable.CommandResponse, SessionError>) -> Void`
    public func start<T>(with runnable: T, completion: @escaping CompletionResult<T.CommandResponse>) where T : CardSessionRunnable {
        start {[weak self] session, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if (runnable is ReadCommand) && self.environment.card != nil { //We already done ReadCommand on iOS 13 for cards
                self.handleRunnableCompletion(runnableResult: .success(self.environment.card as! T.CommandResponse), completion: completion)
                return
            }
            
            runnable.run(in: self) {result in
                self.handleRunnableCompletion(runnableResult: result, completion: completion)
            }
        }
    }
    
    /// Starts a card session and performs preflight `Read` command.
    /// - Parameter callback: Delegate with the card session. Can contain error
    public func start(_ callback: @escaping (CardSession, SessionError?) -> Void) {
        guard TangemSdk.isNFCAvailable else {
            callback(self, .unsupportedDevice)
            return
        }
        
        guard !isBusy else {
            callback(self, .busy)
            return
        }
        
        setBusy(true)
        
        reader.tag
            .dropFirst()
            .filter { [unowned self] in $0 == nil || self.environment.card == nil && self.sendSubscription.isEmpty }
            .sink(receiveCompletion: { [unowned self] readerCompletion in
                if case let .failure(error) = readerCompletion, self.environment.card == nil && self.sendSubscription.isEmpty {
                    callback(self, error)
                    self.stop(error: error)
                }}, receiveValue: { [unowned self] tag in
                    if let tag = tag {
                        self.viewDelegate.tagConnected()
                        self.initializeSession(tag, callback)
                    } else {
                        self.environment.encryptionKey = nil
                        self.viewDelegate.tagLost()
                    }
            })
            .store(in: &connectedTagSubscription)
        
        reader.startSession(with: initialMessage)
    }
    
    /// Stops the current session with the text message. If nil, the default message will be shown
    /// - Parameter message: The message to show
    public func stop(message: String? = nil) {
        if let message = message {
            viewDelegate.showAlertMessage(message)
        }
        reader.stopSession()
        setBusy(false)
        connectedTagSubscription = []
        sendSubscription = []
    }
    
    /// Stops the current session with the error message.  Error's `localizedDescription` will be used
    /// - Parameter error: The error to show
    public func stop(error: Error) {
        reader.stopSession(with: error.localizedDescription)
        setBusy(false)
        connectedTagSubscription = []
        sendSubscription = []
    }
    
    /// Restarts the polling sequence so the reader session can discover new tags.
    public func restartPolling() {
        reader.restartPolling()
    }
    
    /// Sends `CommandApdu` to the current card
    /// - Parameters:
    ///   - apdu: The apdu to send
    ///   - completion: Completion handler. Invoked by nfc-reader
    public final func send(apdu: CommandApdu, completion: @escaping CompletionResult<ResponseApdu>) {
        reader.tag
            .compactMap{ $0 }
            .sink(receiveCompletion: { readerCompletion in
                if case let .failure(error) = readerCompletion {
                    completion(.failure(error))
                }
            }, receiveValue: { [unowned self] _ in
                self.reader.send(apdu: apdu) { [weak self] result in
                    self?.sendSubscription = []
                    completion(result)
                }
            })
            .store(in: &sendSubscription)
    }
    
    private func handleRunnableCompletion<TResponse>(runnableResult: Result<TResponse, SessionError>, completion: @escaping CompletionResult<TResponse>) {
        switch runnableResult {
        case .success(let runnableResponse):
            stop(message: Localization.nfcAlertDefaultDone)
            DispatchQueue.main.async { completion(.success(runnableResponse)) }
        case .failure(let error):
            stop(error: error)
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }
    
    private func setBusy(_ isBusy: Bool) {
        semaphore.wait()
        defer { semaphore.signal() }
        self.isBusy = isBusy
    }
    
    @available(iOS 13.0, *)
    private func initializeSession(_ tagType: NFCTagType, _ callback: @escaping (CardSession, SessionError?) -> Void) {
        let readCommand = ReadCommand()
        switch tagType {
        case .tag:
            readCommand.run(in: self) { [weak self] readResult in
                guard let self = self else { return }
                
                switch readResult {
                case .success(let readResponse):
                    if let expectedCardId = self.cardId?.uppercased(),
                        let actualCardId = readResponse.cardId?.uppercased(),
                        expectedCardId != actualCardId {
                        let error = SessionError.wrongCard
                        callback(self, error)
                        self.stop(error: error)
                        return
                    }
                    
                    self.environment.card = readResponse
                    callback(self, nil)
                case .failure(let error):
                    if !self.tryHandleError(error) {
                        callback(self, error)
                        self.stop(error: error)
                    }
                }
            }
        case .slix2:
            self.reader.readSlix2Tag() {[weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let responseApdu):
                    do {
                        self.environment.card = try readCommand.deserialize(with: self.environment, from: responseApdu)
                        self.stop()
                        callback(self, nil)
                    } catch {
                        let sessionError = error.toSessionError()
                        self.stop(error: sessionError)
                        callback(self, sessionError)
                    }
                case .failure(let error):
                    self.stop(error: error)
                    callback(self, error)
                }
            }
        default:
            assertionFailure("Unsupported tag")
            callback(self, .unknownError)
        }
    }
    
    private func tryHandleError(_ error: SessionError) -> Bool {
        switch error {
        case .needEncryption:
            //TODO: handle need encryption
            return false
        default:
            return false
        }
    }
}
