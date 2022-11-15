//
//  ServicesManager.swift
//  Tangem
//
//  Created by Alexander Osokin on 13.05.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Foundation
import Combine

class ServicesManager {
    @Injected(\.userWalletRepository) private var userWalletRepository: UserWalletRepository
    @Injected(\.exchangeService) private var exchangeService: ExchangeService
    @Injected(\.tangemApiService) private var tangemApiService: TangemApiService

    private var bag = Set<AnyCancellable>()

    func initialize() {
        exchangeService.initialize()
        tangemApiService.initialize()
    }
}

protocol Initializable {
    func initialize()
}
