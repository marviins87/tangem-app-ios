//
//  ExpressFeeSelectorView.swift
//  Tangem
//
//  Created by Sergey Balashov on 31.10.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import SwiftUI

struct ExpressFeeSelectorView: View {
    @ObservedObject private var viewModel: ExpressFeeSelectorViewModel

    init(viewModel: ExpressFeeSelectorViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: .zero) {
            BottomSheetHeaderView(title: Localization.commonFeeSelectorTitle)

            GroupedSection(viewModel.feeRowViewModels) {
                FeeRowView(viewModel: $0)
            } footer: {
                DefaultFooterView(Localization.commonFeeSelectorFooter)
            }
            .backgroundColor(Colors.Background.action)
            .interItemSpacing(0)
            .verticalPadding(10)
            .horizontalPadding(14)
            .separatorStyle(.minimum)
            .padding(.horizontal, 14)
        }
    }
}

struct ExpressFeeSelectorView_Preview: PreviewProvider {
    struct StatableContainer: View {
        @ObservedObject private var coordinator = BottomSheetCoordinator()

        var body: some View {
            ZStack {
                Colors.Background.primary
                    .edgesIgnoringSafeArea(.all)

                Button("Bottom sheet isShowing \((coordinator.item != nil).description)") {
                    coordinator.toggleItem()
                }
                .font(Fonts.Bold.body)
                .offset(y: -200)

                NavHolder()
                    .bottomSheet(item: $coordinator.item) {
                        ExpressFeeSelectorView(viewModel: $0)
                    }
            }
        }
    }

    class BottomSheetCoordinator: ObservableObject, ExpressFeeSelectorRoutable {
        @Published var item: ExpressFeeSelectorViewModel?

        func toggleItem() {
            // TODO: https://tangem.atlassian.net/browse/IOS-5212
        }

        func closeExpressFeeSelector() {
            item = nil
        }
    }

    static var previews: some View {
        StatableContainer()
            .preferredColorScheme(.light)

        StatableContainer()
            .preferredColorScheme(.dark)
    }
}