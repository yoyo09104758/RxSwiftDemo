//
//  RxNetworkExt.swift
//  RxNetwork_Example
//
//  Created by GorXion on 2018/5/28.
//  Copyright © 2018年 CocoaPods. All rights reserved.
//

import RxSwiftX
import RxSwift
import Moya

extension Network {
    
    struct Response<T: Codable>: Codable {
        let code: Int
        let message: String
        let result: T
        
        var success: Bool {
            return code == 2000
        }
    }
}

extension Network {
    
    enum Error: Swift.Error {
        case status(code: Int, message: String)
        
        var code: Int {
            switch self {
            case .status(let code, _):
                return code
            }
        }
        
        var message: String {
            switch self {
            case .status(_, let message):
                return message
            }
        }
        
        var localizedDescription: String {
            return message
        }
    }
}

extension PrimitiveSequence where TraitType == SingleTrait, ElementType: Moya.Response {
    
    func mapResult<T: Codable>(_ type: T.Type,
                               atKeyPath keyPath: String? = nil,
                               using decoder: JSONDecoder = .init()) -> Single<T> {
        return flatMap { response -> Single<T> in
            guard let resp = try? response.map(Network.Response<T>.self) else {
                return Single.error(MoyaError.jsonMapping(response))
            }
            if resp.success { return Single.just(resp.result) }
            return Single.error(Network.Error.status(code: resp.code, message: resp.message))
        }
    }
}

extension PrimitiveSequence where TraitType == SingleTrait, ElementType: TargetType {
    
    func requestWithResult<T: Codable>(_ type: T.Type,
                                       atKeyPath keyPath: String? = nil,
                                       using decoder: JSONDecoder = .init()) -> Single<T> {
        return flatMap { target -> Single<T> in
            target.request().map(Network.Response<T>.self, atKeyPath: keyPath, using: decoder).map({
                if $0.success { return $0.result }
                throw Network.Error.status(code: $0.code, message: $0.message)
            }).storeCachedObject(for: target)
        }
    }
}

extension ObservableType where E: TargetType {
    
    func requestWithResult<T: Codable>(_ type: T.Type,
                                       atKeyPath keyPath: String? = nil,
                                       using decoder: JSONDecoder = .init()) -> Observable<T> {
        return flatMap { target -> Observable<T> in
            let result = target.request().map(Network.Response<T>.self, atKeyPath: keyPath, using: decoder).map({ response -> T in
                if response.success { return response.result }
                throw Network.Error.status(code: response.code, message: response.message)
            }).storeCachedObject(for: target).asObservable()
            
            if let object = target.cachedObject(type) {
                return result.startWith(object)
            }
            return result
        }
    }
}
