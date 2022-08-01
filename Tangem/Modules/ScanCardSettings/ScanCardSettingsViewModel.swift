//
//  ScanCardSettingsViewModel.swift
//  Tangem
//
//  Created by Sergey Balashov on 26.07.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Combine
import SwiftUI

final class ScanCardSettingsViewModel: ObservableObject {
    @Injected(\.tangemSdkProvider) private var sdkProvider: TangemSdkProviding

    @Published var isLoading: Bool = false
    @Published var alert: AlertBinder?

    private unowned let coordinator: ScanCardSettingsRoutable

    init(coordinator: ScanCardSettingsRoutable) {
        self.coordinator = coordinator
    }
}

// MARK: - View Output

extension ScanCardSettingsViewModel {
    func scanCard() {
        scan { [weak self] result in
            switch result {
            case let .success(cardInfo):
                let cardModel = CardViewModel(cardInfo: cardInfo)
                cardModel.updateState()
                self?.coordinator.openCardSettings(cardModel: cardModel)
            case let .failure(error):
                self?.showErrorAlert(error: error)
            }
        }
    }
}

// MARK: - Private

extension ScanCardSettingsViewModel {
    func scan(completion: @escaping (Result<CardInfo, Error>) -> Void) {
        sdkProvider.prepareScan()
        sdkProvider.sdk.startSession(with: AppScanTask(targetBatch: nil)) { result in
            switch result {
            case .failure(let error):
                Analytics.logCardSdkError(error, for: .scan)
                completion(.failure(error))
            case .success(let response):
                completion(.success(response.getCardInfo()))
            }
        }
    }

    func showErrorAlert(error: Error) {
        let alert = Alert(
            title: Text("common_error"),
            message: Text(error.localizedDescription),
            dismissButton: .default(Text("common_ok"))
        )

        self.alert = AlertBinder(alert: alert)
    }
}