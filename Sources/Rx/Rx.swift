//
//  Rx.swift
//  VDAsync
//
//  Created by Daniil on 10.08.2019.
//

import RxSwift

extension Promise: PrimitiveSequenceType {
    
    public var primitiveSequence: PrimitiveSequence<SingleTrait, T> {
        return asSingle().primitiveSequence
    }
    
    public func asSingle() -> Single<T> {
        return Single.create(subscribe: { event -> Disposable in
            Async.execute {
                event(.success(self.await()))
            }
            return Disposables.create()
        })
    }
    
}

extension PromiseTry: PrimitiveSequenceType {
    
    public var primitiveSequence: PrimitiveSequence<SingleTrait, T> {
        return asSingle().primitiveSequence
    }
    
    public func asSingle() -> Single<T> {
        return Single.create(subscribe: { event -> Disposable in
            Async.execute {
                try event(.success(self.await()))
            }.catch {
                event(.error($0))
            }
            return Disposables.create()
        })
    }
    
}
