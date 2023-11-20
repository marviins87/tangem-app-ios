//
//  ExpressWallet.swift
//  TangemSwapping
//
//  Created by Sergey Balashov on 09.11.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation

public protocol ExpressWallet {
    var expressCurrency: ExpressCurrency { get }
    var defaultAddress: String { get }
    var decimalCount: Int { get }

    func getBalance() async throws -> Decimal
    func getCoinBalance() async throws -> Decimal
}

public extension ExpressWallet {
    var contractAddress: String {
        expressCurrency.contractAddress
    }

    var network: String {
        expressCurrency.network
    }

    var isToken: Bool {
        contractAddress != ExpressConstants.coinContractAddress
    }

    func getBalanceInWEI() async throws -> Decimal {
        try await convertToWEI(value: getBalance())
    }

    func getCoinBalanceInWEI() async throws -> Decimal {
        try await convertToWEI(value: getCoinBalance())
    }

    // Maybe will be deleted. We still deciding, How it will work
    func convertToWEI(value: Decimal) -> Decimal {
        let decimalValue = pow(10, decimalCount)
        return value * decimalValue
    }

    // Maybe will be deleted. We still deciding, How it will work
    func convertFromWEI(value: Decimal) -> Decimal {
        let decimalValue = pow(10, decimalCount)
        return value / decimalValue
    }
}
