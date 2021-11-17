//
//  CreateWalletAndReadOriginCardTask.swift
//  Tangem
//
//  Created by Andrew Son on 27.09.2021.
//  Copyright © 2021 Tangem AG. All rights reserved.
//

import TangemSdk

class CreateWalletAndReadOriginCardTask: CardSessionRunnable {
    private var linkingCommand: StartOriginCardLinkingCommand? = nil
    
    func run(in session: CardSession, completion: @escaping CompletionResult<(OriginCard?, Card)>) {
        let createWalletsTask = CreateMultiWalletTask(curves: [.secp256k1, .ed25519, .secp256r1])
        createWalletsTask.run(in: session) { result in
            switch result {
            case .success:
                guard let card = session.environment.card else {
                    completion(.failure(.missingOriginCard))
                    return
                }
                
                self.readOriginCard(card, in: session, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func readOriginCard(_ card: Card, in session: CardSession, completion: @escaping CompletionResult<(OriginCard?, Card)>) {
        linkingCommand = StartOriginCardLinkingCommand()
        linkingCommand!.run(in: session) { result in
            switch result {
            case .success(let originCard):
                completion(.success((originCard, card)))
            case .failure:
                completion(.success((nil, card)))
            }
        }
    }
    
}