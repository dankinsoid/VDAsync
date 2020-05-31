//
//  Async.swift
//  VDAsync
//
//  Created by Daniil on 10.08.2019.
//

import Foundation

public enum Async {
    
    @discardableResult
    public static func execute(on queue: DispatchQueue = DispatchQueue.global(qos: .utility), _ block: @escaping () throws -> ()) -> Async.Catch<Error> {
        return queue.async(block)
    }
    
    public static func execute(on queue: DispatchQueue = DispatchQueue.global(qos: .utility), _ block: @escaping () -> ()) {
        queue.async(execute: block)
    }
    
}

extension Async {

    public final class Catch<Failure: Error> {
        internal var queue: DispatchQueue?
        internal var block: ((Failure) -> ())?
        
        public func `catch`(_ block: @escaping (Failure) -> ()) {
            if let queue = self.queue {
                self.block = { e in queue.async { block(e) } }
            } else {
                self.block = block
            }
        }
    }
    
}
