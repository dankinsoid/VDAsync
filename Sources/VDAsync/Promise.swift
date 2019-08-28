import Foundation
import UnwrapOperator
import Promises

extension Promise {
    
    public static func wrap<E: Error>(_ block: (@escaping (Result<Value, E>) -> ()) -> ()) -> Promise<Value> {
        let promise = Promise<Value>.pending()
        block {
            promise.put($0)
        }
        return promise
    }
    
    public static func wrap<E: Error, A>(_ block: (A, @escaping (Result<Value,  E>) -> ()) -> (), _ value: A) -> Promise<Value> {
        return wrap { block(value, $0) }
    }
    
    public static func wrap(_ block: (@escaping (Value) -> ()) -> ()) -> Promise<Value> {
        let promise = Promise<Value>.pending()
        block(promise.fulfill)
        return promise
    }
    
    public static func wrap(_ block: (_ success: @escaping (Value) -> (), _ failure: @escaping (Error) -> ()) -> ()) -> Promise<Value> {
        let promise = Promise<Value>.pending()
        block(promise.fulfill, promise.reject)
        return promise
    }
    
    public static func wrap(_ block: (@escaping (Value?, Error?) -> ()) -> ()) -> Promise<Value> {
        let promise = Promise<Value>.pending()
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
    
    public static func wrap<A>(_ block: (A, @escaping (Value?, Error?) -> ()) -> (), _ first: A) -> Promise<Value> {
        return wrap({ block(first, $0) })
    }
    
    public static func wrap<A, B>(_ block: (A, B, @escaping (Value?, Error?) -> ()) -> (), _ first: A, _ second: B) -> Promise<Value> {
        return wrap({ block(first, second, $0) })
    }
    
    public static func wrap<A, B, C>(_ block: (A, B, C, @escaping (Value?, Error?) -> ()) -> (), _ first: A, _ second: B, _ third: C) -> Promise<Value> {
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
    
    public func await() throws -> Value {
        return try Promises.await(self)
    }
    
    public func `catch`(with value: Value) -> Promise<Value> {
        return Promise<Value> { fulfill, reject in
            self.then(fulfill).catch { _ in
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

extension Promise where Value == Void {
    
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
    
}
