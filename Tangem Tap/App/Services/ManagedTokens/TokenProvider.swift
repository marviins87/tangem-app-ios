//
//  TokenProvider.swift
//  Tangem Tap
//
//  Created by Andrew Son on 15/02/21.
//  Copyright © 2021 Tangem AG. All rights reserved.
//

import Foundation
import BlockchainSdk

protocol TokenProvider {
    var tokens: [Token] { get }
}

class ERC20TokenProvider: TokenProvider {
    
    private let fileName = "erc20tokens"
    
    private(set) var tokens: [Token] = []
    
    static let instance = ERC20TokenProvider()
    
    private init() {
        guard let tokens = try? JsonUtils.readBundleFile(with: fileName, type: [Token].self, shouldAddCompilationCondition: false) else {
            print("Failed to find erc 20 tokens json file")
            return
        }
        self.tokens = tokens
    }
    
}