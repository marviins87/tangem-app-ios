//
//  SendFeeView.swift
//  Tangem
//
//  Created by Andrey Chukavin on 30.10.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import SwiftUI

struct SendFeeView: View {
    let namespace: Namespace.ID

    @ObservedObject var viewModel: SendFeeViewModel

    let bottomSpacing: CGFloat

    var body: some View {
        GroupedScrollView(spacing: 20) {
            GroupedSection(viewModel.feeRowViewModels) {
                if $0.isSelected.value {
                    FeeRowView(viewModel: $0)
                        .setNamespace(namespace)
                        .setIconNamespaceId(SendViewNamespaceId.feeIcon.rawValue)
                        .setTitleNamespaceId(SendViewNamespaceId.feeTitle.rawValue)
                        .setSubtitleNamespaceId(SendViewNamespaceId.feeSubtitle.rawValue)
                } else {
                    if !viewModel.animatingAuxiliaryViewsOnAppear {
                        FeeRowView(viewModel: $0)
                            .transition(SendView.Constants.auxiliaryViewTransition)
                    }
                }
            } footer: {
                if !viewModel.animatingAuxiliaryViewsOnAppear {
                    feeSelectorFooter
                        .style(Fonts.Regular.caption1, color: Colors.Text.tertiary)
                        .environment(\.openURL, OpenURLAction { url in
                            viewModel.openFeeExplanation()
                            return .handled
                        })
                        .transition(SendView.Constants.auxiliaryViewTransition)
                }
            }
            .backgroundColor(Colors.Background.action, id: SendViewNamespaceId.feeContainer.rawValue, namespace: namespace)

            if !viewModel.animatingAuxiliaryViewsOnAppear {
                ForEach(viewModel.feeLevelsNotificationInputs) { input in
                    NotificationView(input: input)
                        .transition(SendView.Constants.auxiliaryViewTransition)
                }
            }

            if !viewModel.animatingAuxiliaryViewsOnAppear,
               viewModel.showCustomFeeFields,
               let customFeeModel = viewModel.customFeeModel,
               let customFeeGasPriceModel = viewModel.customFeeGasPriceModel,
               let customFeeGasLimitModel = viewModel.customFeeGasLimitModel {
                Group {
                    SendCustomFeeInputField(viewModel: customFeeModel)
                    SendCustomFeeInputField(viewModel: customFeeGasPriceModel)
                    SendCustomFeeInputField(viewModel: customFeeGasLimitModel)
                }
                .transition(SendView.Constants.auxiliaryViewTransition)

                ForEach(viewModel.customFeeNotificationInputs) { input in
                    NotificationView(input: input)
                        .transition(SendView.Constants.auxiliaryViewTransition)
                }
            }

            if !viewModel.animatingAuxiliaryViewsOnAppear {
                GroupedSection(viewModel.subtractFromAmountModel) {
                    DefaultToggleRowView(viewModel: $0)
                } footer: {
                    DefaultFooterView(viewModel.subtractFromAmountFooterText)
                        .animation(.default, value: viewModel.subtractFromAmountFooterText)
                }
                .transition(SendView.Constants.auxiliaryViewTransition)

                ForEach(viewModel.feeCoverageNotificationInputs) { input in
                    NotificationView(input: input)
                        .transition(SendView.Constants.auxiliaryViewTransition)
                }
            }

            Spacer(minLength: bottomSpacing)
        }
        .background(Colors.Background.tertiary.edgesIgnoringSafeArea(.all))
        .onAppear(perform: viewModel.onAppear)
    }

    private var feeSelectorFooter: some View {
        Text(Localization.commonFeeSelectorFooter) + Text(" ") + Text("[\(Localization.commonReadMore)](\(viewModel.feeExplanationUrl.absoluteString))")
    }
}

struct SendFeeView_Previews: PreviewProvider {
    @Namespace static var namespace

    static let tokenIconInfo = TokenIconInfo(
        name: "Tether",
        blockchainIconName: "ethereum.fill",
        imageURL: IconURLBuilder().tokenIconURL(id: "tether"),
        isCustom: false,
        customTokenColor: nil
    )

    static let walletInfo = SendWalletInfo(
        walletName: "Wallet",
        balanceValue: 12013,
        balance: "12013",
        blockchain: .ethereum(testnet: false),
        currencyId: "tether",
        feeCurrencySymbol: "ETH",
        feeCurrencyId: "ethereum",
        isFeeApproximate: false,
        tokenIconInfo: tokenIconInfo,
        cryptoIconURL: URL(string: "https://s3.eu-central-1.amazonaws.com/tangem.api/coins/large/tether.png")!,
        cryptoCurrencyCode: "USDT",
        fiatIconURL: URL(string: "https://vectorflags.s3-us-west-2.amazonaws.com/flags/us-square-01.png")!,
        fiatCurrencyCode: "USD",
        amountFractionDigits: 6,
        feeFractionDigits: 6,
        feeAmountType: .coin
    )

    static var previews: some View {
        SendFeeView(namespace: namespace, viewModel: SendFeeViewModel(input: SendFeeViewModelInputMock(), notificationManager: FakeSendNotificationManager(), walletInfo: walletInfo), bottomSpacing: 150)
    }
}
