//
//  CoinModel.swift
//  Tangem
//
//  Created by Alexander Osokin on 16.03.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Foundation
import BlockchainSdk
import TangemSdk

struct CoinModel {
    let id: String
    let name: String
    let symbol: String
    let items: [TokenItem]
}

extension CoinModel {
    var blockchain: Blockchain? {
        if let coin = items.first(where: { $0.isBlockchain }) {
            return coin.blockchain
        } else {
            return items.first?.blockchain
        }
    }
}
