//
//  ExpressNotificationEvent.swift
//  Tangem
//
//  Created by Andrew Son on 21/11/23.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import SwiftUI

enum ExpressNotificationEvent {
    case permissionNeeded(currencyCode: String)
    case refreshRequired(title: String, message: String)
    case hasPendingTransaction(symbol: String)
    case hasPendingApproveTransaction
    case notEnoughFeeForTokenTx(mainTokenName: String, mainTokenSymbol: String, blockchainIconName: String)
    case tooSmallAmountToSwap(minimumAmountText: String)
    case tooBigAmountToSwap(maximumAmountText: String)
    case notEnoughReserveToSwap(maximumAmountText: String)
    case noDestinationTokens(sourceTokenName: String)
    case verificationRequired
    case cexOperationFailed
    case feeWillBeSubtractFromSendingAmount
    case existentialDepositWarning(blockchainName: String, amount: String)
    case dustAmount(minimumAmountText: String, minimumChangeText: String)
    case withdrawalWarning(amount: Decimal, amountFormatted: String)
}

extension ExpressNotificationEvent: NotificationEvent {
    var title: NotificationView.Title {
        switch self {
        case .permissionNeeded:
            return .string(Localization.expressProviderPermissionNeeded)
        case .refreshRequired(let title, _):
            return .string(title)
        case .hasPendingTransaction:
            return .string(Localization.warningExpressActiveTransactionTitle)
        case .hasPendingApproveTransaction:
            return .string(Localization.warningExpressApprovalInProgressTitle)
        case .notEnoughFeeForTokenTx(let mainTokenName, _, _):
            return .string(Localization.warningExpressNotEnoughFeeForTokenTxTitle(mainTokenName))
        case .tooSmallAmountToSwap(let minimumAmountText):
            return .string(Localization.warningExpressTooMinimalAmountTitle(minimumAmountText))
        case .tooBigAmountToSwap(let maximumAmountText):
            return .string(Localization.warningExpressTooMaximumAmountTitle(maximumAmountText))
        case .notEnoughReserveToSwap(let maximumAmountText):
            return .string(Localization.sendNotificationInvalidReserveAmountTitle(maximumAmountText))
        case .noDestinationTokens:
            return .string(Localization.warningExpressNoExchangeableCoinsTitle)
        case .verificationRequired:
            return .string(Localization.expressExchangeNotificationVerificationTitle)
        case .cexOperationFailed:
            return .string(Localization.expressExchangeNotificationFailedTitle)
        case .feeWillBeSubtractFromSendingAmount:
            return .string(Localization.sendNetworkFeeWarningTitle)
        case .existentialDepositWarning:
            return .string(Localization.warningExistentialDepositTitle)
        case .dustAmount:
            return .string(Localization.sendNotificationInvalidAmountTitle)
        case .withdrawalWarning:
            return .string(Localization.sendAlertFeeIncreasedTitle)
        }
    }

    var description: String? {
        switch self {
        case .permissionNeeded(let currencyCode):
            return Localization.swappingPermissionSubheader(currencyCode)
        case .refreshRequired(_, let message):
            return message
        case .hasPendingTransaction(let symbol):
            return Localization.warningExpressActiveTransactionMessage(symbol)
        case .hasPendingApproveTransaction:
            return Localization.warningExpressApprovalInProgressMessage
        case .notEnoughFeeForTokenTx(let mainTokenName, let mainTokenSymbol, _):
            return Localization.warningExpressNotEnoughFeeForTokenTxDescription(mainTokenName, mainTokenSymbol)
        case .tooSmallAmountToSwap, .tooBigAmountToSwap:
            return Localization.warningExpressWrongAmountDescription
        case .notEnoughReserveToSwap:
            return Localization.sendNotificationInvalidReserveAmountText
        case .noDestinationTokens(let sourceTokenName):
            return Localization.warningExpressNoExchangeableCoinsDescription(sourceTokenName)
        case .verificationRequired:
            return Localization.expressExchangeNotificationVerificationText
        case .cexOperationFailed:
            return Localization.expressExchangeNotificationFailedText
        case .feeWillBeSubtractFromSendingAmount:
            return Localization.swappingNetworkFeeWarningContent
        case .existentialDepositWarning(let blockchainName, let amount):
            return Localization.warningExistentialDepositMessage(blockchainName, amount)
        case .dustAmount(let minimumAmountText, let minimumChangeText):
            return Localization.warningExpressDustMessage(minimumAmountText, minimumChangeText)
        case .withdrawalWarning(_, let amountFormatted):
            return Localization.sendNotificationHighFeeText(amountFormatted)
        }
    }

    var colorScheme: NotificationView.ColorScheme {
        switch self {
        case .permissionNeeded,
             .hasPendingTransaction,
             .hasPendingApproveTransaction,
             .tooSmallAmountToSwap,
             .tooBigAmountToSwap,
             .notEnoughReserveToSwap,
             .noDestinationTokens,
             .feeWillBeSubtractFromSendingAmount,
             .existentialDepositWarning,
             .dustAmount:
            return .secondary
        case .notEnoughFeeForTokenTx, .refreshRequired, .verificationRequired, .cexOperationFailed, .withdrawalWarning:
            return .action
        }
    }

    var icon: NotificationView.MessageIcon {
        switch self {
        case .permissionNeeded:
            return .init(iconType: .image(Assets.swapLock.image))
        case .refreshRequired, .noDestinationTokens, .verificationRequired, .feeWillBeSubtractFromSendingAmount:
            return .init(iconType: .image(Assets.attention.image))
        case .hasPendingApproveTransaction:
            return .init(iconType: .progressView)
        case .notEnoughFeeForTokenTx(_, _, let blockchainIconName):
            return .init(iconType: .image(Image(blockchainIconName)))
        case .tooSmallAmountToSwap,
             .tooBigAmountToSwap, .notEnoughReserveToSwap, .cexOperationFailed, .dustAmount:
            return .init(iconType: .image(Assets.redCircleWarning.image))
        case .hasPendingTransaction, .existentialDepositWarning, .withdrawalWarning:
            return .init(iconType: .image(Assets.blueCircleWarning.image))
        }
    }

    var severity: NotificationView.Severity {
        switch self {
        case .permissionNeeded,
             .hasPendingTransaction,
             .hasPendingApproveTransaction,
             .verificationRequired,
             .feeWillBeSubtractFromSendingAmount:
            return .info
        case .notEnoughFeeForTokenTx,
             .tooSmallAmountToSwap,
             .tooBigAmountToSwap,
             .notEnoughReserveToSwap,
             .existentialDepositWarning,
             .noDestinationTokens,
             .dustAmount,
             .withdrawalWarning:
            return .warning
        case .refreshRequired,
             .cexOperationFailed:
            return .critical
        }
    }

    var buttonActionType: NotificationButtonActionType? {
        switch self {
        case .notEnoughFeeForTokenTx(_, let mainTokenSymbol, _):
            return .openFeeCurrency(currencySymbol: mainTokenSymbol)
        case .refreshRequired:
            return .refresh
        case .verificationRequired, .cexOperationFailed:
            return .goToProvider
        case .withdrawalWarning(let amount, let amountFormatted):
            return .reduceAmountTo(amount: amount, amountFormatted: amountFormatted)
        default:
            return nil
        }
    }

    var isWithLoader: Bool {
        switch self {
        case .refreshRequired:
            return true
        default:
            return false
        }
    }

    var removingOnFullLoadingState: Bool {
        switch self {
        case .noDestinationTokens, .refreshRequired, .verificationRequired, .cexOperationFailed:
            return false
        case .permissionNeeded,
             .hasPendingTransaction,
             .hasPendingApproveTransaction,
             .notEnoughFeeForTokenTx,
             .tooSmallAmountToSwap,
             .tooBigAmountToSwap,
             .notEnoughReserveToSwap,
             .feeWillBeSubtractFromSendingAmount,
             .existentialDepositWarning,
             .dustAmount,
             .withdrawalWarning:
            return true
        }
    }

    var isDismissable: Bool {
        return false
    }
}

// MARK: Analytics

// TODO: Add analytics
extension ExpressNotificationEvent {
    var analyticsEvent: Analytics.Event? {
        return nil
    }

    var analyticsParams: [Analytics.ParameterKey: String] {
        return [:]
    }

    var isOneShotAnalyticsEvent: Bool {
        return false
    }
}
