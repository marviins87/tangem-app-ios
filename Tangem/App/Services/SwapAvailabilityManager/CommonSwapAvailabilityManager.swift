//
//  CommonSwapAvailabilityManager.swift
//  Tangem
//
//  Created by Andrew Son on 27/09/23.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Combine
import BlockchainSdk
import TangemSwapping

class CommonSwapAvailabilityManager: SwapAvailabilityManager {
    @Injected(\.tangemApiService) private var tangemApiService: TangemApiService

    var tokenItemsAvailableToSwapPublisher: AnyPublisher<[TokenItem: Bool], Never> {
        loadedSwapableTokenItems.eraseToAnyPublisher()
    }

    private var loadedSwapableTokenItems: CurrentValueSubject<[TokenItem: Bool], Never> = .init([:])

    init() {}

    func loadSwapAvailability(for items: [TokenItem], forceReload: Bool) {
        if items.isEmpty {
            return
        }

        let filteredItemsToRequest = items.filter {
            // If `forceReload` flag is true we need to force reload state for all items
            return loadedSwapableTokenItems.value[$0] == nil || forceReload
        }

        // This mean that all requesting items in blockchains that currently not available for swap
        // We can exit without request
        if filteredItemsToRequest.isEmpty {
            return
        }

        let requestItem = convertToRequestItem(filteredItemsToRequest)
        var loadSubscription: AnyCancellable?
        loadSubscription = tangemApiService
            .loadCoins(requestModel: .init(supportedBlockchains: requestItem.blockchains, ids: requestItem.currencyIds))
            .sink(receiveCompletion: { _ in
                withExtendedLifetime(loadSubscription) {}
            }, receiveValue: { [weak self] models in
                guard let self else {
                    return
                }

                let loadedTokenItems = models.flatMap { $0.items }

                let preparedSwapStates: [TokenItem: Bool] = loadedTokenItems.reduce(into: [:]) { result, item in
                    let exchangeable: Bool = {
                        switch item {
                        case .token(let token, _):
                            return token.exchangeable ?? false
                        case .blockchain(let blockchain):
                            return self.supportedBlockchains.contains(blockchain)
                        }
                    }()

                    result.updateValue(exchangeable, forKey: item)
                }

                var items = loadedSwapableTokenItems.value
                preparedSwapStates.forEach { key, value in
                    items.updateValue(value, forKey: key)
                }
                loadedSwapableTokenItems.value = items
            })
    }

    func canSwap(tokenItem: TokenItem) -> Bool {
        loadedSwapableTokenItems.value[tokenItem] ?? false
    }

    private func convertToRequestItem(_ items: [TokenItem]) -> RequestItem {
        var blockchains = Set<Blockchain>()
        var currencyIds = [String]()

        items.forEach { item in
            blockchains.insert(item.blockchain)
            guard let currencyId = item.currencyId else {
                return
            }

            currencyIds.append(currencyId)
        }
        return .init(blockchains: blockchains, currencyIds: currencyIds)
    }
}

private extension CommonSwapAvailabilityManager {
    struct RequestItem: Hashable {
        let blockchains: Set<Blockchain>
        let currencyIds: [String]
    }
}
