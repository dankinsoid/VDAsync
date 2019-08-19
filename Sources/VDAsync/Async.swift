//
//  Async.swift
//  VDAsync
//
//  Created by Daniil on 10.08.2019.
//

import Foundation

public enum Async {
    
    @discardableResult
    public static func execute(on queue: DispatchQueue = DispatchQueue.global(qos: .utility), _ block: @escaping () throws -> ()) -> Async.Catch {
        return queue.async(block)
    }
    
    public static func execute(on queue: DispatchQueue = DispatchQueue.global(qos: .utility), _ block: @escaping () -> ()) {
        queue.async(execute: block)
    }
    
    public static func promise<T, E: Error>(_ block: (@escaping (Result<T,  E>) -> ()) -> ()) -> PromiseTry<T> {
        let promise = PromiseTryBuilder<T>()
        block {
            promise.put($0)
        }
        return promise.promise
    }
    
    public static func promise<T, E: Error, A>(_ block: (A, @escaping (Result<T,  E>) -> ()) -> (), _ value: A) -> PromiseTry<T> {
        return promise { block(value, $0) }
    }
    
    public static func promise<T>(_ block: (@escaping (T) -> ()) -> ()) -> Promise<T> {
        let builder = PromiseBuilder<T>()
        block(builder.put)
        return builder.promise
    }
    
    public static func promise<T>(_ block: (_ success: @escaping (T) -> (), _ failure: @escaping (Error) -> ()) -> ()) -> PromiseTry<T> {
        let builder = PromiseTryBuilder<T>()
        block(builder.put, builder.throw)
        return builder.promise
    }
    
    public static func promise<T>(_ block: (@escaping (T?, Error?) -> ()) -> ()) -> PromiseTry<T> {
        let promise = PromiseTryBuilder<T>()
        block {
            if let result = $0 {
                promise.put(result)
            } else if let error = $1 {
                promise.throw(error)
            } else {
                promise.throw(Async.Errors.noElements)
            }
        }
        return promise.promise
    }
    
    public static func promise(_ block: (@escaping (Error?) -> ()) -> ()) -> PromiseTry<Void> {
        let promise = PromiseTryBuilder<Void>()
        block {
            if let error = $0 {
                promise.throw(error)
            } else {
                promise.put(())
            }
        }
        return promise.promise
    }
    
    public static func promise<A>(_ block: (A, @escaping (Error?) -> ()) -> (), _ first: A) -> PromiseTry<Void> {
        return promise({ block(first, $0) })
    }
    
    public static func promise<T, A>(_ block: (A, @escaping (T?, Error?) -> ()) -> (), _ first: A) -> PromiseTry<T> {
        return promise({ block(first, $0) })
    }
    
    public static func promise<T, A, B>(_ block: (A, B, @escaping (T?, Error?) -> ()) -> (), _ first: A, _ second: B) -> PromiseTry<T> {
        return promise({ block(first, second, $0) })
    }
    
    public static func promise<T, A, B, C>(_ block: (A, B, C, @escaping (T?, Error?) -> ()) -> (), _ first: A, _ second: B, _ third: C) -> PromiseTry<T> {
        return promise({ block(first, second, third, $0) })
    }
    
    public static func promise<T>(_ block: @escaping () throws -> T) -> PromiseTry<T> {
        return PromiseTry(block)
    }
    
    public static func promise<T>(_ block: @escaping () -> T) -> Promise<T> {
        return Promise(block)
    }
}

extension Async {

    public final class Catch {
        internal var queue: DispatchQueue?
        internal var block: ((Error) -> ())?
        
        public func `catch`(_ block: @escaping (Error) -> ()) {
            if let queue = self.queue {
                self.block = { e in queue.async { block(e) } }
            } else {
                self.block = block
            }
        }
    }
    
    public enum Errors: Error {
        case noElements
    }
    
}
