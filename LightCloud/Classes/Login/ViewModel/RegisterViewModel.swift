//
//  RegisterViewModel.swift
//  LightCloud
//
//  Created by GorXion on 2018/5/10.
//  Copyright © 2018年 gaoX. All rights reserved.
//

import RxSwift
import RxCocoa

final class RegisterViewModel {
    
    struct Input {
        let username: ControlProperty<String>
        let password: ControlProperty<String>
        let register: ControlEvent<Void>
    }
    
    struct Output {
        let validation: Driver<Bool>
        let register: Observable<Bool>
        let state: Observable<NetworkState>
    }
}

extension RegisterViewModel: ViewModelType {
    
    func transform(_ input: RegisterViewModel.Input) -> RegisterViewModel.Output {
        
        let validation = Observable.combineLatest(input.username, input.password) {
            !$0.isEmpty && !$1.isEmpty
            }.asDriver(onErrorJustReturn: false)
        
        let usernameAndPassword = Observable.combineLatest(input.username, input.password) { (username: $0, password: $1) }
        let user = AVUser()
        
        let register = input.register.withLatestFrom(usernameAndPassword).flatMapLatest({
            user.rx.register(username: $0.username, password: $0.password).loading().catchErrorJustShow("failure")
        })
        
        let state = register.map({ _ in
            NetworkState.success("success")
        })
        
        return Output(validation: validation, register: register, state: state)
    }
}
