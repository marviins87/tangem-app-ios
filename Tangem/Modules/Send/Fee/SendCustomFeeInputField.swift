//
//  SendCustomFeeInputField.swift
//  Tangem
//
//  Created by Andrey Chukavin on 13.11.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import SwiftUI
import Combine

class SendCustomFeeInputFieldModel: Identifiable {
    let title: String
    let footer: String
    var amount: Binding<DecimalNumberTextField.DecimalValue?>
    let fractionDigits: Int

    @Published var amountAlternative: String?

    private var bag: Set<AnyCancellable> = []

    init(title: String, footer: String, amount: Binding<DecimalNumberTextField.DecimalValue?>, fractionDigits: Int, amountAlternativePublisher: AnyPublisher<String?, Never>) {
        self.title = title
        self.footer = footer
        self.amount = amount
        self.fractionDigits = fractionDigits

        amountAlternativePublisher
            .assign(to: \.amountAlternative, on: self, ownership: .weak)
            .store(in: &bag)
    }
}

struct SendCustomFeeInputField: View {
    let viewModel: SendCustomFeeInputFieldModel

    var body: some View {
        GroupedSection(viewModel) { viewModel in
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title)
                    .style(Fonts.Regular.footnote, color: Colors.Text.secondary)

                HStack {
                    DecimalNumberTextField(
                        decimalValue: viewModel.amount,
                        decimalNumberFormatter: .init(maximumFractionDigits: viewModel.fractionDigits),
                        font: Fonts.Regular.subheadline
                    )

                    if let amountAlternative = viewModel.amountAlternative {
                        Text(amountAlternative)
                            .style(Fonts.Regular.subheadline, color: Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 14)
        } footer: {
            Text(viewModel.footer)
                .style(Fonts.Regular.caption1, color: Colors.Text.tertiary)
        }
    }
}

#Preview {
    GroupedScrollView {
        SendCustomFeeInputField(
            viewModel: SendCustomFeeInputFieldModel(
                title: "Fee up to",
                footer: "Maximum commission amount",
                amount: .constant(.internal(1234)),
                fractionDigits: 2,
                amountAlternativePublisher: .just(output: "0.41 $")
            )
        )

        SendCustomFeeInputField(
            viewModel: SendCustomFeeInputFieldModel(
                title: "Fee up to",
                footer: "Maximum commission amount",
                amount: .constant(.internal(1234)),
                fractionDigits: 2,
                amountAlternativePublisher: .just(output: nil)
            )
        )
    }
    .background(Colors.Background.secondary.edgesIgnoringSafeArea(.all))
}
