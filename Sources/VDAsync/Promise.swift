import Foundation
import UnwrapOperator
import Promises

extension Promise {
    
    public static func wrap<T, E: Error>(_ block: (@escaping (Result<T, E>) -> ()) -> ()) -> Promise<T> {
        let promise = Promise<T>.pending()
        block {
            promise.put($0)
        }
        return promise
    }
    
    public static func wrap<T, E: Error, A>(_ block: (A, @escaping (Result<T,  E>) -> ()) -> (), _ value: A) -> Promise<T> {
        return wrap { block(value, $0) }
    }
    
    public static func wrap<T>(_ block: (@escaping (T) -> ()) -> ()) -> Promise<T> {
        let promise = Promise<T>.pending()
        block(promise.fulfill)
        return promise
    }
    
    public static func wrap<T>(_ block: (_ success: @escaping (T) -> (), _ failure: @escaping (Error) -> ()) -> ()) -> Promise<T> {
        let promise = Promise<T>.pending()
        block(promise.fulfill, promise.reject)
        return promise
    }
    
    public static func wrap<T>(_ block: (@escaping (T?, Error?) -> ()) -> ()) -> Promise<T> {
        let promise = Promise<T>.pending()
        block {
            if let result = $0 {
                promise.fulfill(result)
            } else if let error = $1 {
                promise.reject(error)
            } else {
                promise.reject(OptionalException.noValue)
            }
        }
        return promise
    }
    
    public static func wrap(_ block: (@escaping (Error?) -> ()) -> ()) -> Promise<Void> {
        let promise = Promise<Void>.pending()
        block {
            if let error = $0 {
                promise.reject(error)
            } else {
                promise.fulfill(())
            }
        }
        return promise
    }
    
    public static func wrap<A>(_ block: (A, @escaping (Error?) -> ()) -> (), _ first: A) -> Promise<Void> {
        return wrap({ block(first, $0) })
    }
    
    public static func wrap<T, A>(_ block: (A, @escaping (T?, Error?) -> ()) -> (), _ first: A) -> Promise<T> {
        return wrap({ block(first, $0) })
    }
    
    public static func wrap<T, A, B>(_ block: (A, B, @escaping (T?, Error?) -> ()) -> (), _ first: A, _ second: B) -> Promise<T> {
        return wrap({ block(first, second, $0) })
    }
    
    public static func wrap<T, A, B, C>(_ block: (A, B, C, @escaping (T?, Error?) -> ()) -> (), _ first: A, _ second: B, _ third: C) -> Promise<T> {
        return wrap({ block(first, second, third, $0) })
    }
    
    public func put<E: Error>(_ result: Result<Value, E>) {
        switch result {
        case .success(let value):
            fulfill(value)
        case .failure(let error):
            reject(error)
        }
    }
    
    public func map<T>(_ block: @escaping (Value) throws -> T) -> Promise<T> {
        return Promise<T> { fulfill, reject in
            self.then {
                try fulfill(block($0))
            }.catch(reject)
        }
    }
    
    public func await() throws -> Value {
        return try Promises.await(self)
    }
    
    public func `catch`(with value: Value) -> Promise<Value> {
        return Promise<Value> { fulfill, reject in
            self.then {
                try fulfill(block($0))
            }.catch { _ in
                 fulfill(value)
            }
        }
    }
    
    //    public static func promise<T>(_ block: @escaping () throws -> T) -> Promise<T> {
    //        return Promise<T>(block)
    //    }
    
    //    public static func promise<T>(_ block: @escaping () -> T) -> Promise<T> {
    //        return Promise(block)
    //    }
    
}
