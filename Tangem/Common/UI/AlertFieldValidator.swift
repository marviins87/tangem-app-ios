//
//  AlertFieldValidator.swift
//  Tangem
//
//  Created by Andrey Chukavin on 25.09.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import UIKit

class AlertFieldValidator: NSObject {
    private let isValid: (String) -> Bool
    private var acceptButton: UIAlertAction?

    init(isValid: @escaping (String) -> Bool) {
        self.isValid = isValid
    }

    func setAcceptButton(_ acceptButton: UIAlertAction) {
        self.acceptButton = acceptButton
    }
}

extension AlertFieldValidator: UITextFieldDelegate {
    func textFieldDidChangeSelection(_ textField: UITextField) {
        let isValid = isValid(textField.text ?? "")

        let textColor: UIColor?
        if isValid {
            textColor = nil
        } else {
            textColor = UIColor.textWarningColor
        }
        textField.textColor = textColor

        acceptButton?.isEnabled = isValid
    }
}
