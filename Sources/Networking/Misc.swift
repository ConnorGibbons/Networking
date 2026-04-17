//
//  Misc.swift
//  Networking
//
//  Created by Connor Gibbons  on 4/17/26.
//

class Wrapped<T>: @unchecked Sendable {
    var value: T
    
    init(value: T) {
        self.value = value
    }
    
    func update(value: T) {
        self.value = value
    }
    
    func getValue() -> T {
        return value
    }
}
