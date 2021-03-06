//
//  Network+Configuration.swift
//  RxNetwork
//
//  Created by Pircate on 2018/7/7.
//  Copyright © 2018年 Pircate. All rights reserved.
//

import Moya

public let kNetworkTimeoutInterval: TimeInterval = 60

public extension Network {
    
    class Configuration {
        
        public static var `default`: Configuration = Configuration()
        
        public var taskClosure: (TargetType) -> Task = { $0.task }
        
        public var timeoutInterval: TimeInterval = kNetworkTimeoutInterval
        
        public var plugins: [PluginType] = []
        
        public init() {}
    }
}
