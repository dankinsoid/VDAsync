//
//  GDC++.swift
//  VDAsync
//
//  Created by Daniil on 10.08.2019.
//

import Foundation

extension DispatchQueue {
    
	@discardableResult
	public func async(_ block: @escaping () throws -> Void) -> Async.Catch<Error> {
		let catchError = Async.Catch<Error>()
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
 
	public func asyncBlock<T>(_ block: @escaping (T) -> Void) -> (T) -> Void {
		return { data in
			self.async {
				block(data)
			}
		}
	}
    
	public func asyncBlock(_ block: @escaping () -> Void) -> () -> Void {
		return {
			self.async {
				block()
			}
		}
	}
	
	public func barrier(_ execute: @escaping () -> Void) {
		async(group: nil, qos: qos, flags: .barrier, execute: execute)
	}
	
	@discardableResult
	public func barrier(_ execute: @escaping () throws -> Void) -> Async.Catch<Error> {
		let catchError = Async.Catch<Error>()
		async(group: nil, qos: qos, flags: .barrier) {
			do {
				try execute()
			} catch {
				catchError.block?(error)
			}
		}
		return catchError
	}
	
}
