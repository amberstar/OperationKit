//
//  ReachabilityCondition.swift
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
import SystemConfiguration

public struct ReachabilityCondition: OperationCondition {
    
    public static let hostKey = "Host"
    public static let name = "Reachability"
    
    public let host: NSURL
    
    public init(host: NSURL) {
        self.host = host
    }
    
    // MARK: OperationCondition
    
    public func dependencyForOperation(operation: Operation) -> NSOperation? {
        return nil
    }
    
    public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
        ReachabilityManager.requestReachability(host) { reachable in
            guard reachable else {
                let userInfo = [OperationConditionKey: self.dynamicType.name, ReachabilityCondition.hostKey: self.host]
                let error = NSError(domain: OperationErrorDomainCode, code: OperationErrorCode.ConditionFailed.rawValue, userInfo: userInfo)
                completion(.Failed(error))
                return
            }
            
            completion(.Satisfied)
        }
    }
}

private let defaultReferenceKey = "_defaultReferenceKey"

public enum ReachabilityError: ErrorType {
    case FailedToCreateWithAddress(sockaddr_in)
    case FailedToCreateWithHostname(String)
}

public class ReachabilityManager {
    // Properties
    private static var reachabilityRefs = [String: SCNetworkReachability]()
    private let queue = dispatch_queue_create("com.operations.reachability", DISPATCH_QUEUE_SERIAL)
    
    public private(set) var status: ReachabilityStatus = .NotReachable
    
    public enum ReachabilityStatus {
        case NotReachable, ReachableViaWiFi, ReachableViaWWAN
    }
    
    // MARK: Initialization 
    
    required public init(reference: SCNetworkReachability, host: String = defaultReferenceKey) {
        dispatch_sync(queue) {
            var reachabilityFlags: SCNetworkReachabilityFlags = []
            if SCNetworkReachabilityGetFlags(reference, &reachabilityFlags) {
                if reachabilityFlags.contains(.Reachable) && reachabilityFlags.contains(.IsWWAN) == false {
                    self.status = .ReachableViaWiFi
                }
                else {
                    self.status = .ReachableViaWWAN
                }
            }
            
            if ReachabilityManager.reachabilityRefs.keys.contains(host) == false {
                ReachabilityManager.reachabilityRefs[host] = reference
            }
        }
    }
    
    public convenience init(host: String) throws {
        guard let ref = ReachabilityManager.reachabilityRefs[host] ?? SCNetworkReachabilityCreateWithName(nil, host.cStringUsingEncoding(NSUTF8StringEncoding)!) else {
            throw ReachabilityError.FailedToCreateWithHostname(host)
        }
        
        self.init(reference: ref, host: host)
    }
    
    // MARK: Static methods
    
    public static func reachabilityForInternetConnection() throws -> ReachabilityManager {
        var address = sockaddr_in()
        address.sin_len = UInt8(sizeofValue(address))
        address.sin_family = sa_family_t(AF_INET)
        let ref = withUnsafePointer(&address) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }
        
        guard let reference = ref else { throw ReachabilityError.FailedToCreateWithAddress(address) }
        
        return ReachabilityManager(reference: reference)
    }
    
    /// Naive implementation of the reachability
    /// TODO: VPN, cellular connection.
    public static func requestReachability(url: NSURL, completionHandler: (Bool) -> Void) {
        guard let host = url.host else {
            completionHandler(false)
            return
        }
        
        do {
          let reachabilityManager = try ReachabilityManager(host: host)
          completionHandler(reachabilityManager.status != .NotReachable)
        }
        catch {
            completionHandler(false)
        }
    }
}