//
//  SendDestinationInputViewModel.swift
//  Tangem
//
//  Created by Andrey Chukavin on 07.11.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import SwiftUI

class SendDestinationInputViewModel: Identifiable {
    let name: String
    var input: Binding<String>
    let showAddressIcon: Bool
    let placeholder: String
    let didPasteAddress: ([String]) -> Void

    init(name: String, input: Binding<String>, showAddressIcon: Bool, placeholder: String, didPasteAddress: @escaping ([String]) -> Void) {
        self.name = name
        self.input = input
        self.showAddressIcon = showAddressIcon
        self.placeholder = placeholder
        self.didPasteAddress = didPasteAddress
    }

    func didTapLegacyPasteButton() {
        guard let input = UIPasteboard.general.string else {
            return
        }

        didPasteAddress([input])
    }
}
