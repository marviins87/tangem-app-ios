//
//  FeatureToggleRowViewModel.swift
//  Tangem
//
//  Created by Sergey Balashov on 17.04.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import SwiftUI

struct FeatureToggleRowViewModel {
    let toggle: FeatureToggle
    let isEnabledByDefault: Bool
    let state: Binding<FeatureState>

    var releaseVersionInfo: String {
        toggle.releaseVersion.version ?? "unspecified"
    }

    var stateByDefault: String {
        isEnabledByDefault ? "Enabled" : "Disabled"
    }
}

extension FeatureToggleRowViewModel: Identifiable {
    var id: Int { hashValue }
}

extension FeatureToggleRowViewModel: Hashable {
    static func == (lhs: FeatureToggleRowViewModel, rhs: FeatureToggleRowViewModel) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(toggle)
        hasher.combine(state.wrappedValue)
    }
}
