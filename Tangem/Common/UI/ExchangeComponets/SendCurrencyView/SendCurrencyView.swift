//
//  SendCurrencyView.swift
//  Tangem
//
//  Created by Sergey Balashov on 16.11.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import SwiftUI

struct SendCurrencyView: View {
    private var viewModel: SendCurrencyViewModel
    @Binding private var decimalValue: Decimal?

    private let tokenIconSize = CGSize(width: 36, height: 36)
    private var didTapMaxAmountAction: (() -> Void)?

    init(viewModel: SendCurrencyViewModel, decimalValue: Binding<Decimal?>) {
        self.viewModel = viewModel
        _decimalValue = decimalValue
    }

    var body: some View {
        VStack(spacing: 8) {
            headerLabels

            mainContent
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Colors.Background.primary)
        .cornerRadius(14)
    }

    private var headerLabels: some View {
        HStack(spacing: 0) {
            Text(Localization.exchangeSendViewHeader)
                .style(Fonts.Bold.footnote, color: Colors.Text.tertiary)

            Spacer()

            switch viewModel.balance {
            case .loading:
                SkeletonView()
                    .frame(width: 100, height: 14)
                    .cornerRadius(6)
            case .loaded:
                Text(viewModel.balanceString)
                    .style(Fonts.Regular.footnote, color: Colors.Text.tertiary)
            }
        }
    }

    private var currencyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SendGroupedNumberTextField(decimalValue: $decimalValue)
                .maximumFractionDigits(viewModel.maximumFractionDigits)
                .didTapMaxAmount { didTapMaxAmountAction?() }

            switch viewModel.fiatValue {
            case .loading:
                SkeletonView()
                    .frame(width: 50, height: 14)
                    .cornerRadius(6)
            case .loaded:
                Text(viewModel.fiatValueString)
                    .style(Fonts.Regular.footnote, color: Colors.Text.tertiary)
            }
        }
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 0) {
            currencyContent

            Spacer()

            SwappingTokenIconView(viewModel: viewModel.tokenIcon)
        }
    }
}

// MARK: - Setupable

extension SendCurrencyView: Setupable {
    func didTapMaxAmount(_ action: @escaping () -> Void) -> Self {
        map { $0.didTapMaxAmountAction = action }
    }
}

struct SendCurrencyView_Preview: PreviewProvider {
    @State private static var decimalValue: Decimal? = nil

    static let viewModels: [SendCurrencyViewModel] = [
        SendCurrencyViewModel(
            balance: .loading,
            fiatValue: .loading,
            maximumFractionDigits: 8,
            tokenIcon: SwappingTokenIconViewModel(
                state: .loaded(
                    imageURL: TokenIconURLBuilderMock().iconURL(id: "bitcoin", size: .large),
                    symbol: "BTC"
                )
            )
        ),
        SendCurrencyViewModel(
            balance: .loaded(3043.75),
            fiatValue: .loaded(1000.71),
            maximumFractionDigits: 8,
            tokenIcon: SwappingTokenIconViewModel(
                state: .loaded(
                    imageURL: TokenIconURLBuilderMock().iconURL(id: "bitcoin", size: .large),
                    symbol: "BTC"
                )
            )
        ),
    ]

    static var previews: some View {
        ZStack {
            Colors.Background.secondary

            VStack {
                ForEach(viewModels) {
                    SendCurrencyView(viewModel: $0, decimalValue: $decimalValue)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
