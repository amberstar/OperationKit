//
//  ExclusivityManager.swift
//
//  Copyright © 2016. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import Foundation

class ExclusivityManager {
    
    private let queue = DispatchQueue(label: "com.operationKit.ExclusivityManager")
    private var operations: [String: [Operation]] = [:]
    
    /// a shared instance of the controller
    static let shared = ExclusivityManager()
    
    // MARK: Initialization
    
    private init() {}
    
    // MARK: Instance methods
    
    /// Registers an operation as being mutually exclusive
    func add(_ operation: Operation, categories: [String]) {
        queue.sync {
            for category in categories {
                var operationsWithThisCategory = operations[category] ?? []
                if let last = operationsWithThisCategory.last {
                    operation.addDependency(last)
                }
                
                operationsWithThisCategory.append(operation)
                operations[category] = operationsWithThisCategory
            }
        }
    }
    
    /// Unregisters an operation from being mutually exclusive.
    func removeOperation(operation: Operation, categories: [String]) {
        queue.async {
            for category in categories {
                let matchingOperations = self.operations[category]
                
                if
                    /// the  operations category
                    var operationsWithThisCategory = matchingOperations,
                    
                    /// the index for the operation
                    let index = operationsWithThisCategory.firstIndex(of: operation) {
                    
                    operationsWithThisCategory.remove(at: index)
                    self.operations[category] = operationsWithThisCategory
                }
            }
        }
    }
}
