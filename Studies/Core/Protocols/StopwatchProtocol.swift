//
//  StopwatchProtocol.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/09.
//


import Foundation

protocol StopwatchProtocol: AnyObject {
    var isRunning: Bool { get }
    var elapsedTime: TimeInterval { get }
    var formattedTime: String { get }
    
    func start()
    func stop()
    func reset()
}
