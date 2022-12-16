//
//  CardSettingsRoutable.swift
//  Tangem
//
//  Created by Sergey Balashov on 29.06.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Foundation

protocol CardSettingsRoutable: AnyObject {
    func openOnboarding(with input: OnboardingInput, canSelectDifferentCardAfterReset: Bool)
    func openSecurityMode(cardModel: CardViewModel)
    func openResetCardToFactoryWarning(mainButtonAction: @escaping () -> Void)
    func dismiss()
    func popToRoot()
}
