//
//  StoriesViewModel.swift
//  StoriesDemo
//
//  Created by Andrey Chukavin on 26.01.2022.
//

import Foundation
import Combine
import SwiftUI

class StoriesViewModel: ObservableObject {
    @Published var selection = 0
    @Published var currentProgress = 0.0
    let numberOfViews: Int
    
    private var timerSubscription: AnyCancellable?
    private var longTapTimerSubscription: AnyCancellable?
    private var currentDragLocation: CGPoint?
    
    private let fps: Double = 60
    private let storyDuration: Double
    private let restartAutomatically = true
    private let longTapDuration = 0.5
    
    init(numberOfViews: Int, storyDuration: Double) {
        self.numberOfViews = numberOfViews
        self.storyDuration = storyDuration
    }
    
    func onAppear() {
        DispatchQueue.main.async {
            self.restartTimer()
        }
    }
    
    func didDrag(_ point: CGPoint) {
        currentDragLocation = point
        pauseTimer()
        
        longTapTimerSubscription = Timer.publish(every: longTapDuration, on: RunLoop.main, in: .default)
            .autoconnect()
            .sink { [unowned self] _ in
                self.currentDragLocation = nil
            }
    }
    
    func didEndDrag(_ point: CGPoint, viewWidth: CGFloat) {
        if let currentDragLocation = currentDragLocation {
            let moveForward = currentDragLocation.x > viewWidth / 2
            move(forward: moveForward)
        } else {
            resumeTimer()
        }
        
        currentDragLocation = nil
        longTapTimerSubscription = nil
    }
    
    private func move(forward: Bool) {
        let newIndex = max(0, selection + (forward ? 1 : -1))
        if newIndex < numberOfViews {
            selection = newIndex
            restartTimer()
        } else if restartAutomatically {
            selection = 0
            restartTimer()
        }
    }
    
    private func restartTimer() {
        currentProgress = 0
        resumeTimer()
    }
    
    private func pauseTimer() {
        timerSubscription = nil
    }
    
    private func resumeTimer() {
        timerSubscription = Timer.publish(every: 1 / fps, on: .main, in: .default)
            .autoconnect()
            .sink { [unowned self] _ in
                if self.currentProgress >= 1 {
                    self.move(forward: true)
                } else {
                    self.currentProgress += 1 / self.fps / self.storyDuration
                }
            }
    }
}
