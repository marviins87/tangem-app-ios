//
//  LimitsResponseParser.swift
//  TangemVisa
//
//  Created by Andrew Son on 19/01/24.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation
import BlockchainSdk

struct LimitsResponseParser {
    private let responseLenght = 962
    private let singleValueLength = 64
    private let itemsForEachLimit = 7
    private let amountsCount = 5
    private let numberOfLimits = 3

    func parseResponse(_ response: String) throws -> VisaLimits {
        guard response.count == responseLenght else {
            throw VisaParserError.limitsResponseWrongLength
        }
        var limitsStrings = split(string: response.removeHexPrefix(), by: singleValueLength * itemsForEachLimit)

        guard limitsStrings.count == numberOfLimits else {
            throw VisaParserError.limitsResponseWrongLength
        }

        let oldLimit = try parseLimit(limitsStrings.removeFirst())
        let newLimit = try parseLimit(limitsStrings.removeFirst())
        let timeIntervalWhenLimitsChange = EthereumUtils.parseEthereumDecimal(limitsStrings.removeFirst(), decimalsCount: 0)?.doubleValue ?? 0

        return VisaLimits(
            oldLimit: oldLimit,
            newLimit: newLimit,
            changeDate: Date(timeIntervalSince1970: timeIntervalWhenLimitsChange)
        )
    }

    private func parseLimit(_ limit: String) throws -> VisaLimit {
        guard limit.count == itemsForEachLimit * singleValueLength else {
            throw VisaParserError.limitWrongLength
        }

        var limitItems = split(string: limit, by: singleValueLength)

        guard limitItems.count == itemsForEachLimit else {
            throw VisaParserError.limitWrongLength
        }

        let limitDurationSeconds = EthereumUtils.parseEthereumDecimal(limitItems.removeLast(), decimalsCount: 0)
        let timeIntervalWhenLimitEnds = EthereumUtils.parseEthereumDecimal(limitItems.removeLast(), decimalsCount: 0)
        let dueDate = Date(timeIntervalSince1970: timeIntervalWhenLimitEnds?.doubleValue ?? 0)

        let decimalCount = VisaUtilities().visaBlockchain.decimalCount
        var values = limitItems.map { EthereumUtils.parseEthereumDecimal($0, decimalsCount: decimalCount) }

        guard values.count == amountsCount else {
            throw VisaParserError.failedToParseLimitAmount
        }

        return VisaLimit(
            expirationDate: dueDate,
            limitDurationSeconds: limitDurationSeconds?.doubleValue ?? 0,
            singleTransaction: values.removeFirst(),
            otpLimit: values.removeFirst(),
            spentOTPAmount: values.removeFirst(),
            noOTPLimit: values.removeFirst(),
            spentNoOTPAmount: values.removeFirst()
        )
    }

    private func split(string: String, by length: Int) -> [String] {
        var startIndex = string.startIndex
        var results = [Substring]()

        while startIndex < string.endIndex {
            let endIndex = string.index(startIndex, offsetBy: length, limitedBy: string.endIndex) ?? string.endIndex
            results.append(string[startIndex ..< endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
}