//
//  ScanCardObserver.swift
//  Tangem Tap
//
//  Created by Andrew Son on 20/02/21.
//  Copyright © 2021 Tangem AG. All rights reserved.
//

import Foundation

class FailedCardScanTracker: EmailDataCollector {
    
    private var logger: Logger
    
    var dataForEmail: String {
        "----------\n" + DeviceInfoProvider.info()
    }
    
    var attachment: Data? {
        logger.scanLogFileData
    }
    
    var shouldDisplayAlert: Bool {
        numberOfFailedAttempts >= 2
    }
    
    private var numberOfFailedAttempts: Int = 0
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func resetCounter() {
        numberOfFailedAttempts = 0
    }
    
    func recordFailure() {
        numberOfFailedAttempts += 1
    }
}