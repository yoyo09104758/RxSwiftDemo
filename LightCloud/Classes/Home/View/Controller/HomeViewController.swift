//
//  HomeViewController.swift
//  LightCloud
//
//  Created by GorXion on 2018/5/10.
//  Copyright © 2018年 gaoX. All rights reserved.
//

import UIKit
import LeanCloud
import MJRefresh
import RxDataSources
import FSCycleScrollView
import RxSwiftX

final class HomeViewController: BaseViewController {
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: CGRect.zero, style: .grouped).chain
            .rowHeight(60)
            .register(TodoItemCell.self, forCellReuseIdentifier: "cellID").build
        tableView.mj_header = MJRefreshNormalHeader()
        tableView.tableHeaderView = cycleScrollView
        disablesAdjustScrollViewInsets(tableView)
        return tableView
    }()
    
    private lazy var cycleScrollView: FSCycleScrollView = {
        let cycleScrollView = FSCycleScrollView(frame: CGRect(x: 0, y: 0, width: UIScreen.width, height: 240))
        cycleScrollView.backgroundColor = UIColor(hex: "#4381E8")
        cycleScrollView.isInfinite = true
        return cycleScrollView
    }()
    
    private lazy var proxy: RxTableViewSectionedReloadProxy<TodoSectionModel> = {
        RxTableViewSectionedReloadProxy<TodoSectionModel>(configureCell: { (_, tableView, indexPath, item) -> UITableViewCell in
            let cell = tableView.dequeueReusableCell(withIdentifier: "cellID", for: indexPath) as! TodoItemCell
            cell.bindItem(item)
            return cell
        }, canEditRowAtIndexPath: { _, _ in
            return true
        }, canMoveRowAtIndexPath: { _, _ in
            return true
        }, heightForRowAtIndexPath: { _, _, item in
            return 60
        }, heightForHeaderInSection: { _, _ -> CGFloat in
            return 50
        }, viewForHeaderInSection: { _, _ -> UIView? in
            return UILabel().chain.text("云推荐").textAlignment(.center).build
        })
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigation()
        buildSubviews()
        bindViewModel()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func setupNavigation() {
        navigation.bar.tintColor = UIColor.white
        navigation.item.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: nil, action: nil)
        navigation.item.leftBarButtonItem?.rx.tap.bind(to: rx.push(QueryViewController.self, animated: true)).disposed(by: disposeBag)
        navigation.item.rightBarButtonItem = UIBarButtonItem(title: "登录")
        navigation.item.rightBarButtonItem?.rx.tap.bind(to: rx.gotoLogin).disposed(by: disposeBag)
        
        let editButton = UIButton(type: .custom).chain
            .title("编辑", for: .normal, .highlighted)
            .title("完成", for: .selected, [.selected, .highlighted])
            .systemFont(ofSize: 16).build
        navigation.item.titleView = editButton
        
        let isSelected = editButton.rx.tap.map(to: !editButton.isSelected ).shareOnce()
        isSelected.bind(to: editButton.rx.isSelected).disposed(by: disposeBag)
        isSelected.bind(to: tableView.rx.isEditing).disposed(by: disposeBag)
        // 编辑状态禁用下拉刷新
        isSelected.map(!).bind(to: tableView.rx.bounces).disposed(by: disposeBag)
    }
    
    private func buildSubviews() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        tableView.mj_header.beginRefreshing()
    }
    
    private func bindViewModel() {
        let viewModel = HomeViewModel()
        let input = HomeViewModel.Input(refresh: tableView.mj_header.rx.refreshing.shareOnce(),
                                        itemDeleted: tableView.rx.itemDeleted,
                                        dataSource: Observable.of(proxy))
        let output = viewModel.transform(input)
        
        output.items.drive(tableView.rx.items(proxy: proxy)).disposed(by: disposeBag)
        
        output.banners.bind { [weak self] images in
            self?.cycleScrollView.dataSourceType = .onlyImage(images: images)
        }.disposed(by: disposeBag)
        
        // 请求完成结束刷新
        output.items.mapVoid.drive(tableView.mj_header.rx.endRefreshing).disposed(by: disposeBag)
        
        output.state.drive(Toast.rx.state).disposed(by: disposeBag)
        
        output.itemDeleted.subscribeNext(weak: self, { (self) in
            { self.itemDeleted(at: $0) }
        }).disposed(by: disposeBag)
        
        itemMovedBind(proxy)
        
        contentOffsetBindNavigationBar()
    }
    
    private func contentOffsetBindNavigationBar() {
        tableView.rx.contentOffset.map({ offset in
            offset.y > 0 ? offset.y / (240 - (UIApplication.shared.statusBarFrame.maxY + 44)) : 0
        }).bind(to: navigation.bar.rx.alpha).disposed(by: disposeBag)
    }
    
    // cell 删除操作
    private func itemDeleted(at indexPath: IndexPath) {
        var sections = proxy.sectionModels
        var items = sections[indexPath.section].items
        items.remove(at: indexPath.row)
        if items.isEmpty {
            sections.remove(at: indexPath.section)
            proxy.setSections(sections)
            tableView.deleteSections([indexPath.section], animationStyle: .automatic)
        } else {
            sections[indexPath.section].items = items
            proxy.setSections(sections)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    // cell 移动操作
    private func itemMovedBind(_ proxy: RxTableViewSectionedReloadProxy<TodoSectionModel>) {
        tableView.rx.itemMoved.subscribe(onNext: { (from, to) in
            let sections = proxy.sectionModels
            let item = proxy[from]
            var fromItems = sections[from.section].items
            var toItems = sections[to.section].items
            fromItems.remove(at: from.item)
            toItems.insert(item, at: to.row)
            proxy.setSections(sections)
        }).disposed(by: disposeBag)
    }
}
