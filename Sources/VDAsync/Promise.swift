import Foundation
import UnwrapOperator

fileprivate final class AnyPromise<T> {
    private var value: T?
    private let semaphore = DispatchSemaphore(value: 0)
    private var semaphoreCount = 0
    private let lock = NSLock()
    
    init(_ block: @escaping () -> T) {
        Async.execute {
            let _value = block()
            self.put(_value)
        }
    }
    
    init() {}
    
    func put(_ value: T) {
        lock.lock()
        self.value = value
        if semaphoreCount > 0 {
            for _ in 0..<semaphoreCount {
                semaphore.signal()
            }
        }
        semaphoreCount = 0
        lock.unlock()
    }
    
    func await() -> T? {
        if let result = value {
            return result
        }
        semaphoreCount += 1
        semaphore.wait()
        return value
    }
    
}

public final class Promise<T> {
    private let promise: AnyPromise<T>
    
    public init(_ block: @escaping () -> T) {
        promise = AnyPromise(block)
    }
    
    public init() {
        promise = AnyPromise()
    }
    
    public init(_ value: T) {
        promise = AnyPromise()
        put(value)
    }
    
    public func await() -> T {
        return promise.await()!
    }
    
    public func async(_ block: @escaping (T) -> ()) {
        Async.execute {
            block(self.await())
        }
    }
    
    public func put(_ value: T) {
        promise.put(value)
    }
    
    public func map<R>(_ transform: @escaping (T) -> R) -> Promise<R> {
        return Promise<R> {
            return transform(self.await())
        }
    }
    
    public func map<R>(_ transform: @escaping (T) throws -> R) -> PromiseTry<R> {
        return PromiseTry<R> {
            return try transform(self.await())
        }
    }
    
}

public final class PromiseTry<T> {
    private let promise: AnyPromise<Result<T, Error>>
    
    public static func value(_ value: T) -> PromiseTry<T> {
        return PromiseTry(value)
    }
    
    public static func error(_ error: Error) -> PromiseTry<T> {
        return PromiseTry(error: error)
    }
    
    public init(_ block: @escaping () throws -> T) {
        promise = AnyPromise {
            return Result(catching: block)
        }
    }
    
    public init(_ value: T) {
        promise = AnyPromise()
        put(.success(value))
    }
    
    public init(error: Error) {
        promise = AnyPromise()
        put(.failure(error))
    }
    
    public init() {
        promise = AnyPromise()
    }
    
    public func await() throws -> T {
        return try promise.await()~!.get()
    }
    
    public func put(_ value: T) {
        promise.put(.success(value))
    }
    
    public func `throw`(_ value: Error) {
        promise.put(.failure(value))
    }
    
    public func put(_ value: Result<T, Error>) {
        promise.put(value)
    }
    
    public func put<E: Error>(_ value: Result<T, E>) {
        promise.put(value.mapError({ $0 as Error }))
    }
    
    @discardableResult
    public func async(_ block: @escaping (T) throws -> ()) -> Async.Catch {
        return Async.execute {
            try block(self.await())
        }
    }
    
    public func `do`(onSuccess: ((T) -> ())?, onError: ((Error) -> ())? = nil) -> PromiseTry<T> {
        return Async.promise {
            do {
                let value = try self.await()
                onSuccess?(value)
                return value
            } catch {
                onError?(error)
                throw(error)
            }
        }
    }
    
    @discardableResult
    public func asyncOnMain(_ block: @escaping (T) throws -> ()) -> Async.Catch {
        let handler = Async.Catch()
        handler.queue = DispatchQueue.main
        let completion: (T) -> () = { v in DispatchQueue.main.async { try block(v) }.catch { e in handler.block?(e) } }
        Async.execute {
            let result = try self.await()
            completion(result)
            }.catch { error in
                handler.block?(error)
        }
        return handler
    }
    
    public func map<R>(_ transform: @escaping (T) throws -> R) -> PromiseTry<R> {
        return PromiseTry<R> {
            return try transform(self.await())
        }
    }
    
}
