//
//  CardViewModel.swift
//  Tangem
//
//  Created by Alexander Osokin on 18.07.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk
import BlockchainSdk
import Combine
import Alamofire
import SwiftUI

class CardViewModel: Identifiable, ObservableObject {
    // MARK: Services

    @Injected(\.tangemApiService) var tangemApiService: TangemApiService
    @Injected(\.userWalletRepository) private var userWalletRepository: UserWalletRepository

    let walletModelsManager: WalletModelsManager

    var userTokensManager: UserTokensManager { _userTokensManager }

    private lazy var _userTokensManager = CommonUserTokensManager(
        userWalletId: userWalletId,
        shouldLoadSwapAvailability: config.hasFeature(.swapping),
        userTokenListManager: userTokenListManager,
        walletModelsManager: walletModelsManager,
        derivationStyle: config.derivationStyle,
        derivationManager: derivationManager,
        cardDerivableProvider: self,
        existingCurves: config.walletCurves,
        longHashesSupported: longHashesSupported
    )

    let userTokenListManager: UserTokenListManager

    private let keysRepository: KeysRepository
    private let walletManagersRepository: WalletManagersRepository
    private let cardImageProvider = CardImageProvider()

    lazy var derivationManager: DerivationManager? = {
        guard config.hasFeature(.hdWallets) else {
            return nil
        }

        let commonDerivationManager = CommonDerivationManager(
            keysRepository: keysRepository,
            userTokenListManager: userTokenListManager
        )

        commonDerivationManager.delegate = self
        return commonDerivationManager
    }()

    let warningsService = WarningsService()

    @Published private(set) var currentSecurityOption: SecurityModeOption = .longTap

    var signer: TangemSigner { _signer }

    var cardInteractor: CardInteractor {
        .init(cardInfo: cardInfo)
    }

    var cardId: String { cardInfo.card.cardId }

    var card: CardDTO {
        cardInfo.card
    }

    var walletData: DefaultWalletData {
        cardInfo.walletData
    }

    var batchId: String { cardInfo.card.batchId }
    var cardPublicKey: Data { cardInfo.card.cardPublicKey }

    var supportsOnlineImage: Bool {
        config.hasFeature(.onlineImage)
    }

    var isMultiWallet: Bool {
        config.hasFeature(.multiCurrency)
    }

    var canDisplayHashesCount: Bool {
        config.hasFeature(.displayHashesCount)
    }

    var emailConfig: EmailConfig? {
        config.emailConfig
    }

    var cardsCount: Int {
        config.cardsCount
    }

    var cardIdFormatted: String {
        cardInfo.cardIdFormatted
    }

    var cardIssuer: String {
        cardInfo.card.issuer.name
    }

    var cardSignedHashes: Int {
        cardInfo.card.walletSignedHashes
    }

    var artworkInfo: ArtworkInfo? {
        cardImageProvider.cardArtwork(for: cardInfo.card.cardId)?.artworkInfo
    }

    var name: String {
        cardInfo.name
    }

    var defaultName: String {
        config.cardName
    }

    var canCreateBackup: Bool {
        !config.getFeatureAvailability(.backup).isHidden
    }

    var canSkipBackup: Bool {
        config.canSkipBackup
    }

    var canTwin: Bool {
        config.hasFeature(.twinning)
    }

    var canChangeAccessCodeRecoverySettings: Bool {
        config.hasFeature(.accessCodeRecoverySettings)
    }

    var hasBackupCards: Bool {
        cardInfo.card.backupStatus?.isActive ?? false
    }

    var cardDisclaimer: TOU {
        config.tou
    }

    var canShowSwapping: Bool {
        !config.getFeatureAvailability(.swapping).isHidden
    }

    // Temp for WC. Migrate to userWalletId?
    var secp256k1SeedKey: Data? {
        cardInfo.card.wallets.last(where: { $0.curve == .secp256k1 })?.publicKey
    }

    let userWalletId: UserWalletId

    lazy var totalBalanceProvider: TotalBalanceProviding = TotalBalanceProvider(
        walletModelsManager: walletModelsManager,
        derivationManager: derivationManager
    )

    private(set) var cardInfo: CardInfo
    private var tangemSdk: TangemSdk?
    var config: UserWalletConfig

    var availableSecurityOptions: [SecurityModeOption] {
        var options: [SecurityModeOption] = []

        if canSetLongTap || currentSecurityOption == .longTap {
            options.append(.longTap)
        }

        if config.hasFeature(.accessCode) || currentSecurityOption == .accessCode {
            options.append(.accessCode)
        }

        if config.hasFeature(.passcode) || currentSecurityOption == .passCode {
            options.append(.passCode)
        }

        return options
    }

    var hdWalletsSupported: Bool {
        config.hasFeature(.hdWallets)
    }

    var canSetLongTap: Bool {
        config.hasFeature(.longTap)
    }

    var longHashesSupported: Bool {
        config.hasFeature(.longHashes)
    }

    var cardSetLabel: String? {
        config.cardSetLabel
    }

    var canShowSend: Bool {
        config.hasFeature(.withdrawal)
    }

    var canParticipateInPromotion: Bool {
        config.hasFeature(.promotion)
    }

    var resetToFactoryAvailability: UserWalletFeature.Availability {
        config.getFeatureAvailability(.resetToFactory)
    }

    var shouldShowLegacyDerivationAlert: Bool {
        config.warningEvents.contains(where: { $0 == .legacyDerivation })
    }

    var canExchangeCrypto: Bool { !config.getFeatureAvailability(.exchange).isHidden }

    var userWallet: UserWallet {
        UserWalletFactory().userWallet(from: cardInfo, config: config, userWalletId: userWalletId)
    }

    private var isActive: Bool {
        if let selectedUserWalletId = userWalletRepository.selectedUserWalletId {
            return selectedUserWalletId == userWalletId.value
        } else {
            return true
        }
    }

    private let _updatePublisher: PassthroughSubject<Void, Never> = .init()
    private let _userWalletNamePublisher: CurrentValueSubject<String, Never>
    private let _cardHeaderImagePublisher: CurrentValueSubject<ImageType?, Never>
    private var bag = Set<AnyCancellable>()
    private var signSubscription: AnyCancellable?

    private var _signer: TangemSigner {
        didSet {
            bindSigner()
        }
    }

    convenience init?(userWallet: UserWallet) {
        let cardInfo = userWallet.cardInfo()
        self.init(cardInfo: cardInfo)
    }

    init?(cardInfo: CardInfo) {
        let config = UserWalletConfigFactory(cardInfo).makeConfig()

        guard let userWalletIdSeed = config.userWalletIdSeed,
              let walletManagerFactory = try? config.makeAnyWalletManagerFactory() else {
            return nil
        }

        self.cardInfo = cardInfo
        self.config = config
        keysRepository = CommonKeysRepository(with: cardInfo.card.wallets)

        userWalletId = UserWalletId(with: userWalletIdSeed)
        userTokenListManager = CommonUserTokenListManager(
            userWalletId: userWalletId.value,
            supportedBlockchains: config.supportedBlockchains,
            hdWalletsSupported: config.hasFeature(.hdWallets),
            hasTokenSynchronization: config.hasFeature(.tokenSynchronization),
            defaultBlockchains: config.defaultBlockchains
        )

        walletManagersRepository = CommonWalletManagersRepository(
            keysProvider: keysRepository,
            userTokenListManager: userTokenListManager,
            walletManagerFactory: walletManagerFactory
        )

        walletModelsManager = CommonWalletModelsManager(
            walletManagersRepository: walletManagersRepository,
            walletModelsFactory: config.makeWalletModelsFactory()
        )

        _signer = config.tangemSigner
        _userWalletNamePublisher = .init(cardInfo.name)
        _cardHeaderImagePublisher = .init(config.cardHeaderImage)
        updateCurrentSecurityOption()
        appendPersistentBlockchains()
        bind()

        userTokensManager.sync {}
    }

    deinit {
        Log.debug("CardViewModel deinit 🥳🤟")
    }

    func setupWarnings() {
        warningsService.setupWarnings(
            for: config,
            card: cardInfo.card,
            validator: walletModelsManager.walletModels.first?.signatureCountValidator
        )
    }

    func validate() -> Bool {
        if userWallet.hasBackupErrors == true {
            return false
        }

        var expectedCurves = config.mandatoryCurves
        /// Since the curve `bls12381_G2_AUG` was added later into first generation of wallets,, we cannot determine whether this curve is missing due to an error or because the user did not want to recreate the wallet.
        if config is GenericConfig {
            expectedCurves.remove(.bls12381_G2_AUG)
        }

        let curvesValidator = CurvesValidator(expectedCurves: expectedCurves)
        if !curvesValidator.validate(card.wallets.map { $0.curve }) {
            return false
        }

        let backupValidator = BackupValidator()
        if !backupValidator.validate(card.backupStatus) {
            return false
        }

        return true
    }

    private func appendPersistentBlockchains() {
        guard let persistentBlockchains = config.persistentBlockchains else {
            return
        }

        userTokenListManager.update(.append(persistentBlockchains), shouldUpload: true)
    }

    // MARK: - Security

    func changeSecurityOption(_ option: SecurityModeOption, completion: @escaping (Result<Void, Error>) -> Void) {
        let tangemSdk = makeTangemSdk()
        self.tangemSdk = tangemSdk
        switch option {
        case .accessCode:
            tangemSdk.startSession(
                with: SetUserCodeCommand(accessCode: nil),
                cardId: cardId,
                initialMessage: Message(header: nil, body: Localization.initialMessageChangeAccessCodeBody)
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success:
                    onSecurityOptionChanged(isAccessCodeSet: true, isPasscodeSet: false)
                    Analytics.log(.userCodeChanged)
                    completion(.success(()))
                case .failure(let error):
                    AppLog.shared.error(
                        error,
                        params: [
                            .newSecOption: .accessCode,
                            .action: .changeSecOptions,
                        ]
                    )
                    completion(.failure(error))
                }
            }
        case .longTap:
            tangemSdk.startSession(
                with: SetUserCodeCommand.resetUserCodes,
                cardId: cardId
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success:
                    onSecurityOptionChanged(isAccessCodeSet: false, isPasscodeSet: false)
                    completion(.success(()))
                case .failure(let error):
                    AppLog.shared.error(
                        error,
                        params: [
                            .newSecOption: .longTap,
                            .action: .changeSecOptions,
                        ]
                    )
                    completion(.failure(error))
                }
            }
        case .passCode:
            tangemSdk.startSession(
                with: SetUserCodeCommand(passcode: nil),
                cardId: cardId,
                initialMessage: Message(header: nil, body: Localization.initialMessageChangePasscodeBody)
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success:
                    onSecurityOptionChanged(isAccessCodeSet: false, isPasscodeSet: true)
                    completion(.success(()))
                case .failure(let error):
                    AppLog.shared.error(
                        error,
                        params: [
                            .newSecOption: .passcode,
                            .action: .changeSecOptions,
                        ]
                    )
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Update

    func onSecurityOptionChanged(isAccessCodeSet: Bool, isPasscodeSet: Bool) {
        cardInfo.card.isAccessCodeSet = isAccessCodeSet
        cardInfo.card.isPasscodeSet = isPasscodeSet
        onUpdate()
    }

    func onSigned(_ card: Card) {
        for updatedWallet in card.wallets {
            cardInfo.card.wallets[updatedWallet.publicKey]?.totalSignedHashes = updatedWallet.totalSignedHashes
            cardInfo.card.wallets[updatedWallet.publicKey]?.remainingSignatures = updatedWallet.remainingSignatures
        }

        onUpdate()
    }

    func onBackupCreated(_ card: Card) {
        for updatedWallet in card.wallets {
            cardInfo.card.wallets[updatedWallet.publicKey]?.hasBackup = updatedWallet.hasBackup
        }

        cardInfo.card.settings = CardDTO.Settings(settings: card.settings)
        cardInfo.card.isAccessCodeSet = card.isAccessCodeSet
        cardInfo.card.backupStatus = card.backupStatus
        onUpdate()
    }

    private func onUpdate() {
        AppLog.shared.debug("🔄 Updating CardViewModel with new Card")
        config = UserWalletConfigFactory(cardInfo).makeConfig()
        _cardHeaderImagePublisher.send(config.cardHeaderImage)
        _signer = config.tangemSigner
        updateModel()
        // prevent save until onboarding completed
        if userWalletRepository.contains(userWallet) {
            userWalletRepository.save(userWallet)
        }
        _updatePublisher.send()
    }

    func getDisabledLocalizedReason(for feature: UserWalletFeature) -> String? {
        config.getDisabledLocalizedReason(for: feature)
    }

    private func updateModel() {
        AppLog.shared.debug("🔄 Updating Card view model")
        updateCurrentSecurityOption()

        setupWarnings()
    }

    private func updateCurrentSecurityOption() {
        if cardInfo.card.isAccessCodeSet {
            currentSecurityOption = .accessCode
        } else if cardInfo.card.isPasscodeSet ?? false {
            currentSecurityOption = .passCode
        } else {
            currentSecurityOption = .longTap
        }
    }

    private func bind() {
        bindSigner()
    }

    private func bindSigner() {
        signSubscription = _signer.signPublisher
            .sink { [weak self] card in // TODO: TBD remaining signatures feature
                self?.onSigned(card)
            }
    }
}

extension CardViewModel {
    enum WalletsBalanceState {
        case inProgress
        case loaded
    }
}

extension CardViewModel: WalletConnectUserWalletInfoProvider {
    var wcWalletModelProvider: WalletConnectWalletModelProvider {
        CommonWalletConnectWalletModelProvider(walletModelsManager: walletModelsManager)
    }
}

// TODO: Refactor
extension CardViewModel: TangemSdkFactory {
    func makeTangemSdk() -> TangemSdk {
        config.makeTangemSdk()
    }
}

// MARK: - UserWalletModel

extension CardViewModel: UserWalletModel {
    var emailData: [EmailCollectedData] {
        var data = config.emailData

        let userWalletIdItem = EmailCollectedData(type: .card(.userWalletId), data: userWalletId.stringValue)
        data.append(userWalletIdItem)

        return data
    }

    var backupInput: OnboardingInput? {
        let factory = OnboardingInputFactory(
            cardInfo: cardInfo,
            cardModel: self,
            sdkFactory: config,
            onboardingStepsBuilderFactory: config
        )

        return factory.makeBackupInput()
    }

    var twinInput: OnboardingInput? {
        guard let twinData = cardInfo.walletData.twinData else {
            return nil
        }

        let factory = TwinInputFactory(
            cardInput: .cardModel(self),
            userWalletToDelete: userWallet,
            twinData: twinData,
            sdkFactory: config
        )
        return factory.makeTwinInput()
    }

    var updatePublisher: AnyPublisher<Void, Never> {
        _updatePublisher.eraseToAnyPublisher()
    }

    var tokensCount: Int? {
        walletModelsManager.walletModels.count
    }

    var cardImagePublisher: AnyPublisher<CardImageResult, Never> {
        let artwork: CardArtwork

        if let artworkInfo = artworkInfo {
            artwork = .artwork(artworkInfo)
        } else {
            artwork = .notLoaded
        }

        return cardImageProvider.loadImage(
            cardId: card.cardId,
            cardPublicKey: card.cardPublicKey,
            artwork: artwork
        )
    }

    func updateWalletName(_ name: String) {
        cardInfo.name = name
        _userWalletNamePublisher.send(name)
    }
}

extension CardViewModel: MainHeaderSupplementInfoProvider {
    var cardHeaderImagePublisher: AnyPublisher<ImageType?, Never> { _cardHeaderImagePublisher.removeDuplicates().eraseToAnyPublisher() }

    var userWalletNamePublisher: AnyPublisher<String, Never> { _userWalletNamePublisher.eraseToAnyPublisher() }
}

extension CardViewModel: MainHeaderUserWalletStateInfoProvider {
    var isUserWalletLocked: Bool { userWallet.isLocked }

    var isTokensListEmpty: Bool { userTokenListManager.userTokensList.entries.isEmpty }
}

// TODO: refactor storage to single source
extension CardViewModel: DerivationManagerDelegate {
    func onDerived(_ response: DerivationResult) {
        // tmp sync
        for updatedWallet in response {
            for derivedKey in updatedWallet.value.keys {
                cardInfo.card.wallets[updatedWallet.key]?.derivedKeys[derivedKey.key] = derivedKey.value
            }
        }

        userWalletRepository.save(userWallet)
    }
}

extension CardViewModel: CardDerivableProvider {
    var cardDerivableInteractor: CardDerivable {
        return cardInteractor
    }
}

extension CardViewModel: TotalBalanceProviding {
    var totalBalancePublisher: AnyPublisher<LoadingValue<TotalBalance>, Never> {
        totalBalanceProvider.totalBalancePublisher
    }
}

extension CardViewModel: AnalyticsContextDataProvider {
    func getAnalyticsContextData() -> AnalyticsContextData? {
        return AnalyticsContextData(
            card: card,
            productType: config.productType,
            userWalletId: userWalletId.value,
            embeddedEntry: config.embeddedBlockchain
        )
    }
}

extension CardViewModel: EmailDataProvider {}
