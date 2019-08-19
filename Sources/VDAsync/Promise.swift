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

final class PromiseBuilder<T> {
    let promise = Promise<T>()
    
    func put(_ value: T) {
        promise.promise.put(value)
    }
    
}

final class PromiseTryBuilder<T> {
    let promise = PromiseTry<T>()
    
    func put(_ value: T) {
        promise.promise.put(.success(value))
    }
    
    func `throw`(_ value: Error) {
        promise.promise.put(.failure(value))
    }
    
    func put(_ value: Result<T, Error>) {
        promise.promise.put(value)
    }
    
    func put<E: Error>(_ value: Result<T, E>) {
        promise.promise.put(value.mapError({ $0 as Error }))
    }
    
}

fileprivate final class AnyPromise<T> {
    private var value: T?
    private let semaphore = Semaphore()
    private let lock = NSLock()
    let queue: DispatchQueue
    private let block: (() -> T)?
    var isRunned = false
    
    init(_ block: @escaping () -> T) {
        self.block = block
        queue = DispatchQueue.global(qos: .utility)
    }
    
    private init(on queue: DispatchQueue) {
        self.queue = queue
        block = nil
    }
    
    init() {
        queue = DispatchQueue.global(qos: .utility)
        block = nil
    }
    
    convenience init(_ value: T) {
        self.init()
        put(value)
    }
    
    func run(_ completion: ((T?) -> ())?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunned, let block = self.block else { return false }
        isRunned = true
        queue.async {
            let _value = block()
            self.put(_value)
            completion?(_value)
        }
        return true
    }
    
    fileprivate func put(_ value: T?) {
        lock.lock()
        isRunned = true
        self.value = value
        semaphore.reset()
        lock.unlock()
    }
    
    func await() -> T? {
        if let result = value {
            return result
        }
        _ = run(nil)
        semaphore.wait()
        return value
    }
    
    public func async(on queue: DispatchQueue,_ block: @escaping (T?) -> ()) {
        if run(queue.asyncBlock { block($0) }) {
            return
        }
        queue.async {
            let result = self.await()
            block(result)
        }
    }
    
    public func map<R>(_ transform: @escaping (T) -> R) -> AnyPromise<R> {
        let result = AnyPromise<R>(on: queue)
        queue.async {
            if let value = self.await() {
                result.put(transform(value))
            }
            result.put(nil)
        }
        return result
    }
    
    public func map<R>(_ transform: @escaping (T) throws -> R) -> AnyPromise<Result<R, Error>> {
        let result = AnyPromise<Result<R, Error>>(on: queue)
        queue.async {
            if let value = self.await() {
                result.put(Result(catching: { try transform(value) } ))
            }
            result.put(nil)
        }
        return result
    }
}

public final class Promise<T> {
    fileprivate let promise: AnyPromise<T>
    
    public init(_ block: @escaping () -> T) {
        promise = AnyPromise(block)
    }
    
    fileprivate convenience init() {
        self.init(AnyPromise<T>())
    }
    
    fileprivate init(_ any: AnyPromise<T>) {
        promise = any
    }
    
    public init(_ value: T) {
        promise = AnyPromise(value)
    }
    
    @discardableResult
    public func run() -> Promise {
        _ = promise.run(nil)
        return self
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
        promise.async(on: queue, { block($0!) })
    }
    
    public func map<R>(_ transform: @escaping (T) -> R) -> Promise<R> {
        return Promise<R>(promise.map(transform))
    }
    
    public func map<R>(_ transform: @escaping (T) throws -> R) -> PromiseTry<R> {
        return PromiseTry<R>(promise.map(transform))
    }
    
    public func `do`(_ block: @escaping (T) -> ()) -> Promise<T> {
        return Async.promise {
            let result = self.await()
            block(result)
            return result
        }
    }
}

public final class PromiseTry<T> {
    fileprivate let promise: AnyPromise<Result<T, Error>>
    
    public static func value(_ value: T) -> PromiseTry<T> {
        return PromiseTry(value)
    }
    
    public static func error(_ error: Error) -> PromiseTry<T> {
        return PromiseTry(error: error)
    }
    
    public convenience init(_ block: @escaping () throws -> T) {
        let promise = AnyPromise<Result<T, Error>> {
            return Result(catching: block)
        }
        self.init(promise)
    }
    
    fileprivate convenience init() {
        self.init(AnyPromise<Result<T, Error>>())
    }
    
    public convenience init(_ value: T) {
        self.init(AnyPromise(.success(value)))
    }
    
    public convenience init(_ result: Result<T, Error>) {
        self.init(AnyPromise(result))
    }
    
    public convenience init(error: Error) {
        self.init(AnyPromise(.failure(error)))
    }
    
    fileprivate init(_ promise: AnyPromise<Result<T, Error>>) {
        self.promise = promise
    }
    
    @discardableResult
    public func run() -> PromiseTry {
        _ = promise.run(nil)
        return self
    }
    
    public func await() throws -> T {
        return try promise.await()~!.get()
    }
    
    @discardableResult
    public func async(_ block: @escaping (T) throws -> ()) -> Async.Catch {
        return async(on: promise.queue, block)
    }
    
    public func `do`(onSuccess: ((T) -> ())?, onError: ((Error) -> ())? = nil) -> PromiseTry<T> {
        return Async.promise {
            do {
                let value = try self.await()
                onSuccess?(value)
                return value
            } catch {
                onError?(error)
                throw error
            }
        }
    }
    
    public func async(on queue: DispatchQueue,_ block: @escaping (T) throws -> ()) -> Async.Catch {
        let handler = Async.Catch()
        handler.queue = queue
        promise.async(on: queue) {
            do {
                let result = try $0~!.get()
                try block(result)
            } catch {
                handler.block?(error)
            }
        }
        return handler
    }
    
    @discardableResult
    public func asyncOnMain(_ block: @escaping (T) throws -> ()) -> Async.Catch {
        return async(on: .main, block)
    }
    
    public func map<R>(_ transform: @escaping (T) throws -> R) -> PromiseTry<R> {
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
