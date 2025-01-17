//
//  MultiWalletMainContentViewModel.swift
//  Tangem
//
//  Created by Andrew Son on 28/07/23.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import CombineExt

final class MultiWalletMainContentViewModel: ObservableObject {
    @Injected(\.swapAvailabilityProvider) private var swapAvailabilityProvider: SwapAvailabilityProvider

    // MARK: - ViewState

    @Published var isLoadingTokenList: Bool = true
    @Published var sections: [Section] = []
    @Published var notificationInputs: [NotificationViewInput] = []
    @Published var tokensNotificationInputs: [NotificationViewInput] = []

    @Published var isScannerBusy = false
    @Published var error: AlertBinder? = nil

    weak var delegate: MultiWalletMainContentDelegate?

    var footerViewModel: MainFooterViewModel? {
        guard canManageTokens else { return nil }

        return MainFooterViewModel(
            isButtonDisabled: false,
            buttonTitle: Localization.mainManageTokens,
            buttonAction: weakify(self, forFunction: MultiWalletMainContentViewModel.openManageTokens)
        )
    }

    var isOrganizeTokensVisible: Bool {
        guard canManageTokens else { return false }

        if sections.isEmpty {
            return false
        }

        let numberOfTokens = sections.reduce(0) { $0 + $1.items.count }
        let requiredNumberOfTokens = 2

        return numberOfTokens >= requiredNumberOfTokens
    }

    // MARK: - Dependencies

    private let userWalletModel: UserWalletModel
    private let userWalletNotificationManager: NotificationManager
    private let tokensNotificationManager: NotificationManager
    private let tokenSectionsAdapter: TokenSectionsAdapter
    private let tokenRouter: SingleTokenRoutable
    private let optionsEditing: OrganizeTokensOptionsEditing
    private let rateAppController: RateAppController
    private weak var coordinator: MultiWalletMainContentRoutable?

    private var canManageTokens: Bool { userWalletModel.isMultiWallet }

    private var cachedTokenItemViewModels: [ObjectIdentifier: TokenItemViewModel] = [:]

    private let mappingQueue = DispatchQueue(
        label: "com.tangem.MultiWalletMainContentViewModel.mappingQueue",
        qos: .userInitiated
    )

    private let isPageSelectedSubject = PassthroughSubject<Bool, Never>()
    private var isUpdating = false

    private var bag = Set<AnyCancellable>()

    init(
        userWalletModel: UserWalletModel,
        userWalletNotificationManager: NotificationManager,
        tokensNotificationManager: NotificationManager,
        rateAppController: RateAppController,
        tokenSectionsAdapter: TokenSectionsAdapter,
        tokenRouter: SingleTokenRoutable,
        optionsEditing: OrganizeTokensOptionsEditing,
        coordinator: MultiWalletMainContentRoutable?
    ) {
        self.userWalletModel = userWalletModel
        self.userWalletNotificationManager = userWalletNotificationManager
        self.tokensNotificationManager = tokensNotificationManager
        self.rateAppController = rateAppController
        self.tokenSectionsAdapter = tokenSectionsAdapter
        self.tokenRouter = tokenRouter
        self.optionsEditing = optionsEditing
        self.coordinator = coordinator

        setup()
    }

    func onPullToRefresh(completionHandler: @escaping RefreshCompletionHandler) {
        if isUpdating {
            return
        }

        isUpdating = true
        userWalletModel.userTokensManager.sync { [weak self] in
            self?.isUpdating = false
            completionHandler()
        }
    }

    func deriveEntriesWithoutDerivation() {
        Analytics.log(.mainNoticeScanYourCardTapped)
        isScannerBusy = true
        userWalletModel.userTokensManager.deriveIfNeeded { [weak self] _ in
            DispatchQueue.main.async {
                self?.isScannerBusy = false
            }
        }
    }

    func startBackupProcess() {
        // TODO: Refactor this along with OnboardingInput generation
        if let cardViewModel = userWalletModel as? CardViewModel,
           let input = cardViewModel.backupInput {
            Analytics.log(.mainNoticeBackupWalletTapped)
            coordinator?.openOnboardingModal(with: input)
        }
    }

    func onOpenOrganizeTokensButtonTap() {
        Analytics.log(.buttonOrganizeTokens)
        openOrganizeTokens()
    }

    private func setup() {
        subscribeToTokenListUpdatesIfNeeded()
        bind()
    }

    private func bind() {
        let sourcePublisherFactory = TokenSectionsSourcePublisherFactory()
        let tokenSectionsSourcePublisher = sourcePublisherFactory.makeSourcePublisher(for: userWalletModel)

        let organizedTokensSectionsPublisher = tokenSectionsAdapter
            .organizedSections(from: tokenSectionsSourcePublisher, on: mappingQueue)
            .share(replay: 1)

        organizedTokensSectionsPublisher
            .withWeakCaptureOf(self)
            .map { viewModel, sections in
                return viewModel.convertToSections(sections)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.sections, on: self, ownership: .weak)
            .store(in: &bag)

        organizedTokensSectionsPublisher
            .withWeakCaptureOf(self)
            .sink { viewModel, sections in
                viewModel.removeOldCachedTokenViewModels(sections)
            }
            .store(in: &bag)

        organizedTokensSectionsPublisher
            .map { $0.flatMap(\.items) }
            .removeDuplicates()
            .map { $0.map(\.walletModelId) }
            .withWeakCaptureOf(self)
            .flatMapLatest { viewModel, walletModelIds in
                return viewModel.optionsEditing.save(reorderedWalletModelIds: walletModelIds)
            }
            .sink()
            .store(in: &bag)

        userWalletNotificationManager
            .notificationPublisher
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: \.notificationInputs, on: self, ownership: .weak)
            .store(in: &bag)

        tokensNotificationManager
            .notificationPublisher
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: \.tokensNotificationInputs, on: self, ownership: .weak)
            .store(in: &bag)

        rateAppController.bind(
            isPageSelectedPublisher: isPageSelectedSubject,
            notificationsPublisher1: $notificationInputs,
            notificationsPublisher2: $tokensNotificationInputs
        )
    }

    private func convertToSections(
        _ sections: [TokenSectionsAdapter.Section]
    ) -> [Section] {
        let factory = MultiWalletTokenItemsSectionFactory()

        if sections.count == 1, sections[0].items.isEmpty {
            return []
        }

        return sections.enumerated().map { index, section in
            let sectionViewModel = factory.makeSectionViewModel(from: section.model, atIndex: index)
            let itemViewModels = section.items.map { item in
                switch item {
                case .default(let walletModel):
                    // Fetching existing cached View Model for this Wallet Model, if available
                    let cacheKey = ObjectIdentifier(walletModel)
                    if let cachedViewModel = cachedTokenItemViewModels[cacheKey] {
                        return cachedViewModel
                    }
                    let viewModel = makeTokenItemViewModel(from: item, using: factory)
                    cachedTokenItemViewModels[cacheKey] = viewModel
                    return viewModel
                case .withoutDerivation:
                    return makeTokenItemViewModel(from: item, using: factory)
                }
            }

            return Section(model: sectionViewModel, items: itemViewModels)
        }
    }

    private func makeTokenItemViewModel(
        from sectionItem: TokenSectionsAdapter.SectionItem,
        using factory: MultiWalletTokenItemsSectionFactory
    ) -> TokenItemViewModel {
        return factory.makeSectionItemViewModel(
            from: sectionItem,
            contextActionsProvider: self,
            contextActionsDelegate: self,
            tapAction: weakify(self, forFunction: MultiWalletMainContentViewModel.tokenItemTapped(_:))
        )
    }

    private func removeOldCachedTokenViewModels(_ sections: [TokenSectionsAdapter.Section]) {
        let cacheKeys = sections
            .flatMap(\.walletModels)
            .map(ObjectIdentifier.init)
            .toSet()

        cachedTokenItemViewModels = cachedTokenItemViewModels.filter { cacheKeys.contains($0.key) }
    }

    private func subscribeToTokenListUpdatesIfNeeded() {
        if userWalletModel.userTokenListManager.initialized {
            isLoadingTokenList = false
            return
        }

        var tokenSyncSubscription: AnyCancellable?
        tokenSyncSubscription = userWalletModel.userTokenListManager.initializedPublisher
            .filter { $0 }
            .sink(receiveValue: { [weak self] _ in
                self?.isLoadingTokenList = false
                withExtendedLifetime(tokenSyncSubscription) {}
            })
    }

    private func tokenItemTapped(_ walletModelId: WalletModelId) {
        guard
            let walletModel = userWalletModel.walletModelsManager.walletModels.first(where: { $0.id == walletModelId }),
            TokenInteractionAvailabilityProvider(walletModel: walletModel).isTokenDetailsAvailable()
        else {
            return
        }

        coordinator?.openTokenDetails(for: walletModel, userWalletModel: userWalletModel)
    }
}

// MARK: Hide token

private extension MultiWalletMainContentViewModel {
    func hideTokenAction(for tokenItemViewModel: TokenItemViewModel) {
        let tokenItem = tokenItemViewModel.tokenItem

        if userWalletModel.userTokensManager.canRemove(tokenItem) {
            showHideWarningAlert(tokenItem: tokenItem)
        } else {
            showUnableToHideAlert(currencySymbol: tokenItem.currencySymbol, blockchainName: tokenItem.blockchain.displayName)
        }
    }

    func showHideWarningAlert(tokenItem: TokenItem) {
        error = AlertBuilder.makeAlert(
            title: Localization.tokenDetailsHideAlertTitle(tokenItem.currencySymbol),
            message: Localization.tokenDetailsHideAlertMessage,
            primaryButton: .destructive(Text(Localization.tokenDetailsHideAlertHide)) { [weak self] in
                self?.hideToken(tokenItem: tokenItem)
            },
            secondaryButton: .cancel()
        )
    }

    func showUnableToHideAlert(currencySymbol: String, blockchainName: String) {
        let message = Localization.tokenDetailsUnableHideAlertMessage(
            currencySymbol,
            blockchainName
        )

        error = AlertBuilder.makeAlert(
            title: Localization.tokenDetailsUnableHideAlertTitle(currencySymbol),
            message: message,
            primaryButton: .default(Text(Localization.commonOk))
        )
    }

    func hideToken(tokenItem: TokenItem) {
        userWalletModel.userTokensManager.remove(tokenItem)

        Analytics.log(
            event: .buttonRemoveToken,
            params: [
                Analytics.ParameterKey.token: tokenItem.currencySymbol,
                Analytics.ParameterKey.source: Analytics.ParameterValue.main.rawValue,
            ]
        )
    }
}

// MARK: Navigation

extension MultiWalletMainContentViewModel {
    func openManageTokens() {
        Analytics.log(.buttonManageTokens)

        let shouldShowLegacyDerivationAlert = userWalletModel.config.warningEvents.contains(where: { $0 == .legacyDerivation })
        let settings = LegacyManageTokensSettings(
            supportedBlockchains: userWalletModel.config.supportedBlockchains,
            hdWalletsSupported: userWalletModel.config.hasFeature(.hdWallets),
            longHashesSupported: userWalletModel.config.hasFeature(.longHashes),
            derivationStyle: userWalletModel.config.derivationStyle,
            shouldShowLegacyDerivationAlert: shouldShowLegacyDerivationAlert,
            existingCurves: (userWalletModel as? CardViewModel)?.card.walletCurves ?? []
        )

        coordinator?.openManageTokens(with: settings, userTokensManager: userWalletModel.userTokensManager)
    }

    private func openOrganizeTokens() {
        coordinator?.openOrganizeTokens(for: userWalletModel)
    }

    private func openBuy(for walletModel: WalletModel) {
        if let disabledLocalizedReason = userWalletModel.config.getDisabledLocalizedReason(for: .exchange) {
            error = AlertBuilder.makeDemoAlert(disabledLocalizedReason)
            return
        }

        tokenRouter.openBuyCryptoIfPossible(walletModel: walletModel)
    }

    private func openSell(for walletModel: WalletModel) {
        if let disabledLocalizedReason = userWalletModel.config.getDisabledLocalizedReason(for: .exchange) {
            error = AlertBuilder.makeDemoAlert(disabledLocalizedReason)
            return
        }

        tokenRouter.openSell(for: walletModel)
    }
}

// MARK: - Notification tap delegate

extension MultiWalletMainContentViewModel: NotificationTapDelegate {
    func didTapNotification(with id: NotificationViewId) {
        guard let notification = notificationInputs.first(where: { $0.id == id }) else {
            userWalletNotificationManager.dismissNotification(with: id)
            return
        }

        switch notification.settings.event {
        case let userWalletEvent as WarningEvent:
            handleUserWalletNotificationTap(event: userWalletEvent, id: id)
        default:
            break
        }
    }

    func didTapNotificationButton(with id: NotificationViewId, action: NotificationButtonActionType) {
        switch action {
        case .generateAddresses:
            deriveEntriesWithoutDerivation()
        case .backupCard:
            startBackupProcess()
        default:
            return
        }
    }

    private func handleUserWalletNotificationTap(event: WarningEvent, id: NotificationViewId) {
        switch event {
        default:
            assertionFailure("This event shouldn't have tap action on main screen. Event: \(event)")
        }
    }
}

// MARK: - MainViewPage protocol conformance

extension MultiWalletMainContentViewModel: MainViewPage {
    func onPageAppear() {
        isPageSelectedSubject.send(true)
    }

    func onPageDisappear() {
        isPageSelectedSubject.send(false)
    }
}

// MARK: Context actions

extension MultiWalletMainContentViewModel: TokenItemContextActionsProvider {
    func buildContextActions(for tokenItem: TokenItemViewModel) -> [TokenActionType] {
        guard
            let walletModel = userWalletModel.walletModelsManager.walletModels.first(where: { $0.id == tokenItem.id }),
            TokenInteractionAvailabilityProvider(walletModel: walletModel).isContextMenuAvailable()
        else {
            return [.hide]
        }

        let actionsBuilder = TokenActionListBuilder()
        let utility = ExchangeCryptoUtility(
            blockchain: walletModel.blockchainNetwork.blockchain,
            address: walletModel.defaultAddress,
            amountType: walletModel.amountType
        )

        let canExchange = userWalletModel.config.isFeatureVisible(.exchange)
        // On the Main view we have to hide send button if we have any sending restrictions
        let canSend = userWalletModel.config.hasFeature(.send) && walletModel.sendingRestrictions == .none
        let canSwap = userWalletModel.config.hasFeature(.swapping) && swapAvailabilityProvider.canSwap(tokenItem: tokenItem.tokenItem) && !walletModel.isCustom
        let isBlockchainReachable = !walletModel.state.isBlockchainUnreachable

        return actionsBuilder.buildTokenContextActions(
            canExchange: canExchange,
            canSend: canSend,
            canSwap: canSwap,
            canHide: canManageTokens,
            isBlockchainReachable: isBlockchainReachable,
            exchangeUtility: utility
        )
    }
}

extension MultiWalletMainContentViewModel: TokenItemContextActionDelegate {
    func didTapContextAction(_ action: TokenActionType, for tokenItem: TokenItemViewModel) {
        if case .hide = action {
            hideTokenAction(for: tokenItem)
        }

        guard
            let walletModel = userWalletModel.walletModelsManager.walletModels.first(where: { $0.id == tokenItem.id })
        else {
            return
        }

        switch action {
        case .buy:
            openBuy(for: walletModel)
        case .send:
            tokenRouter.openSend(walletModel: walletModel)
        case .receive:
            tokenRouter.openReceive(walletModel: walletModel)
        case .sell:
            openSell(for: walletModel)
        case .copyAddress:
            UIPasteboard.general.string = walletModel.defaultAddress
            delegate?.displayAddressCopiedToast()
        case .exchange:
            if let disabledLocalizedReason = userWalletModel.config.getDisabledLocalizedReason(for: .swapping) {
                error = AlertBuilder.makeDemoAlert(disabledLocalizedReason)
                return
            }

            Analytics.log(event: .buttonExchange, params: [.token: walletModel.tokenItem.currencySymbol])
            tokenRouter.openExchange(walletModel: walletModel)
        case .hide:
            return
        }
    }
}

// MARK: - Auxiliary types

extension MultiWalletMainContentViewModel {
    typealias Section = SectionModel<SectionViewModel, TokenItemViewModel>

    struct SectionViewModel: Identifiable {
        let id: AnyHashable
        let title: String?
    }
}

// MARK: - Convenience extensions

private extension TokenSectionsAdapter.Section {
    var walletModels: [WalletModel] {
        return items.compactMap(\.walletModel)
    }
}
