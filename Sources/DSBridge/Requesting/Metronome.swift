//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/26.
//

import Foundation

/// A timer.
///
/// This code is copied from [a github gist](https://gist.github.com/danielgalasko/1da90276f23ea24cb3467c33d2c05768).
/// Its doc is listed below:
///
/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52
final class Metronome {
    let timeInterval: TimeInterval
    let queue: DispatchQueue
    var eventHandler: (() -> Void)?
    
    init(timeInterval: TimeInterval, queue: DispatchQueue) {
        self.timeInterval = timeInterval
        self.queue = queue
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(
            deadline: .now() + timeInterval,
            repeating: timeInterval
        )
        timer.setEventHandler(handler: { [weak self] in
            guard let self else { return }
            queue.async {
                self.eventHandler?()
            }
        })
        return timer
    }()

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler { }
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}
