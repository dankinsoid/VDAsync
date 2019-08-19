import Foundation
import UnwrapOperator

fileprivate final class Semaphore {
    private let semaphore = DispatchSemaphore(value: 0)
    private var counter = 0
    
    func reset() {
        guard counter > 0 else { return }
        for _ in 0..<counter {
            semaphore.signal()
        }
        counter = 0
    }
    
    func wait() {
        counter += 1
        semaphore.wait()
    }
    
}

fileprivate final class AnyPromise<T> {
    private var value: T?
    private let semaphore: Semaphore
    private let lock: NSLock
    
    init(_ block: @escaping () -> T) {
        semaphore = Semaphore()
        lock = NSLock()
        Async.execute {
            let _value = block()
            self.put(_value)
        }
    }
    
    init<R>(_ other: AnyPromise<R>, transform: (R) -> T) {
        self.semaphore = other.semaphore
        self.lock = other.lock
        if let _value = other.value {
            self.value = transform(_value)
        }
    }
    
    init() {
        lock = NSLock()
        semaphore = Semaphore()
    }
    
    func put(_ value: T) {
        lock.lock()
        self.value = value
        semaphore.reset()
        lock.unlock()
    }
    
    func await() -> T? {
        if let result = value {
            return result
        }
        semaphore.wait()
        return value
    }
    
    public func map<R>(_ transform: (T) -> R) -> AnyPromise<R> {
        return AnyPromise<R>(self, transform: transform)
    }
    
    public func map<R>(_ transform: (T) throws -> R) -> AnyPromise<Result<R, Error>> {
        return AnyPromise<Result<R, Error>>(self, transform: {
            do {
                return try .success(transform($0))
            } catch {
                return .failure(error)
            }
        })
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
    
    fileprivate init(_ any: AnyPromise<T>) {
        promise = any
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
    
    public func async(on queue: DispatchQueue, _ block: @escaping (T) -> ()) {
        queue.async {
            block(self.await())
        }
    }
    
    public func put(_ value: T) {
        promise.put(value)
    }
    
    public func map<R>(_ transform: (T) -> R) -> Promise<R> {
        return Promise<R>(promise.map(transform))
    }
    
    public func map<R>(_ transform: (T) throws -> R) -> PromiseTry<R> {
        return PromiseTry<R>(promise.map(transform))
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
    
    public convenience init(_ block: @escaping () throws -> T) {
        let promise = AnyPromise {
            return Result(catching: block)
        }
        self.init(promise)
    }
    
    public convenience init(_ value: T) {
        self.init()
        put(.success(value))
    }
    
    public convenience init(error: Error) {
        self.init()
        put(.failure(error))
    }
    
    public convenience init() {
        self.init(AnyPromise())
    }
    
    fileprivate init(_ promise: AnyPromise<Result<T, Error>>) {
        self.promise = promise
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
    
    public func async(on queue: DispatchQueue,_ block: @escaping (T) throws -> ()) -> Async.Catch {
        let handler = Async.Catch()
        handler.queue = queue
        let completion: (T) -> () = { v in queue.async { try block(v) }.catch { e in handler.block?(e) } }
        Async.execute {
            let result = try self.await()
            completion(result)
        }.catch { error in
            handler.block?(error)
        }
        return handler
    }
    
    @discardableResult
    public func asyncOnMain(_ block: @escaping (T) throws -> ()) -> Async.Catch {
        return async(on: .main, block)
    }
    
    public func map<R>(_ transform: (T) throws -> R) -> PromiseTry<R> {
        return PromiseTry<R>(promise.map {
            switch $0 {
            case .success(let result):
                return Result(catching: { try transform(result) })
            case .failure(let error):
                return .failure(error)
            }
        })
    }
    
    public func `catch`(with value: T) -> Promise<T> {
        return Promise<T>(promise.map {
            switch $0 {
            case .success(let value0): return value0
            case .failure: return value
            }
        })
    }
    
}
