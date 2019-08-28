//
//  Rx.swift
//  VDAsync
//
//  Created by Daniil on 10.08.2019.
//

import Promises
import RxSwift

extension Promise {
    
    public func asSingle() -> Single<Value> {
        return Single.create(subscribe: { block -> Disposable in
            self.then {
                block(.success($0))
                }.catch {
                    block(.error($0))
            }
            return Disposables.create()
        })
    }
    
}

extension Single {
    
    public func asPromise() -> Promise<Element> {
        var disposeBag = DisposeBag()
        return Promise { put, reject in
            self.asObservable().subscribe(
                onNext: {
                    put($0)
                    disposeBag = DisposeBag()
            },
                onError: {
                    reject($0)
                    disposeBag = DisposeBag()
            }
                ).disposed(by: disposeBag)
        }
    }
    
}
