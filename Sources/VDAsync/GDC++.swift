//
//  GDC++.swift
//  VDAsync
//
//  Created by Daniil on 10.08.2019.
//

import Foundation

extension DispatchQueue {
    
    @discardableResult
    public func async(_ block: @escaping () throws -> ()) -> Async.Catch {
        let catchError = Async.Catch()
        self.async(execute: {
            do {
                try block()
            } catch {
                catchError.block?(error)
            }
        })
        return catchError
    }
    
}


extension DispatchQueue {
    
    public func sync<T>(_ block: () -> T) -> T {
        var result: T?
        self.sync {
            result = block()
        }
        return result!
    }
    
    public func asyncBlock<T>(_ block: @escaping (T) -> ()) -> (T) -> () {
        return { data in
            self.async {
                block(data)
            }
        }
    }
    
    public func asyncBlock(_ block: @escaping () -> ()) -> () -> () {
        return {
            self.async {
                block()
            }
        }
    }
    
}
