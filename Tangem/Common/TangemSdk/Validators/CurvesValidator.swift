//
//  CurvesValidator.swift
//  Tangem
//
//  Created by Alexander Osokin on 29.12.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk

struct CurvesValidator {
    let expectedCurves: [EllipticCurve]

    func validate(_ curves: [EllipticCurve]) -> Bool {
        let uniqueCurves = Set(curves)

        // check that all curves created without duplicates
        guard curves.count == expectedCurves.count,
              uniqueCurves == Set(expectedCurves) else {
            return false
        }

        return true
    }
}
