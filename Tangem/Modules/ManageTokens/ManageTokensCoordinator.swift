//
//  ManageTokensCoordinator.swift
//  Tangem
//
//  Created by skibinalexander on 14.09.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import Combine

class ManageTokensCoordinator: CoordinatorObject {
    var dismissAction: Action<Void>
    var popToRootAction: Action<PopToRootOptions>

    // MARK: - Root Published

    @Published private(set) var manageTokensViewModel: ManageTokensViewModel? = nil

    // MARK: - Child ViewModels

    @Published var networkSelectorViewModel: ManageTokensNetworkSelectorViewModel? = nil
    @Published var walletSelectorViewModel: WalletSelectorViewModel? = nil

    // MARK: - Init

    required init(dismissAction: @escaping Action<Void>, popToRootAction: @escaping Action<PopToRootOptions>) {
        self.dismissAction = dismissAction
        self.popToRootAction = popToRootAction
    }

    // MARK: - Implmentation

    func start(with options: ManageTokensCoordinator.Options) {
        manageTokensViewModel = .init(searchTextPublisher: options.searchTextPublisher, coordinator: self)
    }
}

extension ManageTokensCoordinator {
    struct Options {
        let searchTextPublisher: AnyPublisher<String, Never>?
    }
}

extension ManageTokensCoordinator: ManageTokensRoutable {
    func openTokenSelector(coinId: String, with tokenItems: [TokenItem]) {
        networkSelectorViewModel = ManageTokensNetworkSelectorViewModel(
            coinId: coinId,
            tokenItems: tokenItems,
            coordinator: self
        )
    }

    func showGenerateAddressesWarning(
        numberOfNetworks: Int,
        currentWalletNumber: Int,
        totalWalletNumber: Int,
        action: @escaping () -> Void
    ) {
        fatalError("\(#function) not implemented yet!")
    }

    func hideGenerateAddressesWarning() {
        fatalError("\(#function) not implemented yet!")
    }
}

extension ManageTokensCoordinator: ManageTokensNetworkSelectorRoutable {
    func openWalletSelector(
        userWallets: [UserWallet],
        currentUserWalletId: Data?,
        delegate: WalletSelectorDelegate?
    ) {
        walletSelectorViewModel = .init(
            userWallets: userWallets,
            currentUserWalletId: currentUserWalletId
        )

        walletSelectorViewModel?.delegate = delegate
    }
}
