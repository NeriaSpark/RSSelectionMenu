//
//  RSSelectionMenuController.swift
//  RSSelectionMenu
//
//  Copyright (c) 2019 Rushi Sangani
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
//

import UIKit

/// RSSelectionMenuController
open class RSSelectionMenu<T>: UIViewController, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate {

    // MARK: - Views
    public var tableView: RSSelectionTableView<T>?
    
    /// SearchBar
    public var searchBar: UISearchBar? {
        return tableView?.searchControllerDelegate?.searchBar
    }
    
    /// NavigationBar
    public var navigationBar: UINavigationBar? {
        return self.navigationController?.navigationBar
    }
    
    // MARK: - Properties
    
    /// dismiss: for Single selection only
    public var dismissAutomatically: Bool = true
    
    /// Indicates whether to dismiss with or without animation when dismissing implicitly (e.g. when tapping 'done')
    public var animated: Bool = true
    
    /// property name or unique key is required when using custom models array or dictionary array as datasource
    public var uniquePropertyName: String?
    
    /// Barbuttons titles
    public var leftBarButtonTitle: String?
    public var rightBarButtonTitle: String?
    
    /// cell selection style
    public var cellSelectionStyle: CellSelectionStyle = .tickmark {
        didSet {
            self.tableView?.setCellSelectionStyle(cellSelectionStyle)
        }
    }
    
    /// maximum selection limit
    public var maxSelectionLimit: UInt? = nil {
        didSet {
            self.tableView?.selectionDelegate?.maxSelectedLimit = maxSelectionLimit
        }
    }
    
    /// Selection menu willAppear handler
    public var onWillAppear:(() -> ())?
    
    /// Selection menu pre-dismissal handler
    public var onWillDismiss:((_ selectedItems: DataSource<T>) -> ())?
    
    @available(*, unavailable, renamed: "onWillDismiss")
    public var onDismiss:((_ selectedItems: DataSource<T>) -> ())?
    
    /// Selection menu post-dismissal handler
    public var onDidDismiss:(() -> ())?
    
    /// Selection menu back button tap handler
    public var onBackButtonTapped:(() -> ())?
    
    // MARK: - Private
    
    /// store reference view controller
    fileprivate weak var parentController: UIViewController?
    
    /// presentation style
    fileprivate var menuPresentationStyle: PresentationStyle = .present
    
    /// navigationbar theme
    fileprivate var navigationBarTheme: NavigationBarTheme?
    
    /// backgroundView
    fileprivate var backgroundView = UIView()
    
    /// Indicates that dismissMenu was called (hence 'Back' button was NOT tapped); used in didMove
    fileprivate var dismissed = false
    
    // MARK: - Init
    
    convenience public init(dataSource: DataSource<T>, cellConfiguration configuration: @escaping UITableViewCellConfiguration<T>) {
        self.init(selectionStyle: .single, dataSource: dataSource, cellConfiguration: configuration)
    }
    
    convenience public init(selectionStyle: SelectionStyle, dataSource: DataSource<T>, cellConfiguration configuration: @escaping UITableViewCellConfiguration<T>) {
        self.init(selectionStyle: selectionStyle, dataSource: dataSource, cellType: .basic, cellConfiguration: configuration)
    }
    
    convenience public init(selectionStyle: SelectionStyle, dataSource: DataSource<T>, cellType: CellType, cellConfiguration configuration: @escaping UITableViewCellConfiguration<T>) {
        self.init()
        
        // data source
        let selectionDataSource = RSSelectionMenuDataSource<T>(dataSource: dataSource, forCellType: cellType, cellConfiguration: configuration)
        
        // delegate
        let selectionDelegate = RSSelectionMenuDelegate<T>(selectedItems: [])
     
        // initilize tableview
        self.tableView = RSSelectionTableView<T>(selectionStyle: selectionStyle, cellType: cellType, dataSource: selectionDataSource, delegate: selectionDelegate, from: self)
    }
    
    // MARK: - Life Cycle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupLayout()        
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView?.reload()
        if let handler = onWillAppear { handler() }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        view.endEditing(true)
    }
    
    override open func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        //Back button tapped
        if parent == nil && !dismissed {
            backButtonTap()
        }
    }
    
    // MARK: - Setup Views
    fileprivate func setupViews() {
        backgroundView.backgroundColor = UIColor.clear
        
        if case .formSheet = menuPresentationStyle {
            backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
            addTapGesture()
        }
        
        backgroundView.addSubview(tableView!)
        view.addSubview(backgroundView)
        
        if let leftBarButtonTitle = leftBarButtonTitle {
            self.navigationController?.navigationBar.topItem?.title = leftBarButtonTitle
        }
        
        // done button
        if showDoneButton() {
            setDoneButton()
        }
        
        // cancel button
        if showCancelButton() {
            setCancelButton()
        }
    }
    
    // MARK: - Setup Layout
    
    fileprivate func setupLayout() {
        if let frame = parentController?.view.bounds {
            self.view.frame = frame
        }
        
        // navigation bar theme
        setNavigationBarTheme()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    
        setTableViewFrame()
    }
    
    /// tableView frame
    fileprivate func setTableViewFrame() {
        
        let window =  UIApplication.shared.delegate?.window
        
        // change border style for formsheet
        if case .formSheet = menuPresentationStyle {
            
            tableView?.layer.cornerRadius = 8
            self.backgroundView.frame = (window??.bounds)!
            var tableViewSize = CGSize.zero
            
            if UIDevice.current.userInterfaceIdiom == .phone {
            
                if UIApplication.shared.statusBarOrientation == .portrait {
                    tableViewSize = CGSize(width: backgroundView.frame.size.width - 80, height: backgroundView.frame.size.height - 260)
                }else {
                    tableViewSize = CGSize(width: backgroundView.frame.size.width - 200, height: backgroundView.frame.size.height - 100)
                }
            }else {
                tableViewSize = CGSize(width: backgroundView.frame.size.width - 300, height: backgroundView.frame.size.height - 400)
            }
            self.tableView?.frame.size = tableViewSize
            self.tableView?.center = self.backgroundView.center
            
        }else {
            self.backgroundView.frame = self.view.bounds
            self.tableView?.frame = backgroundView.frame
        }
    }
    
    /// Tap gesture
    fileprivate func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onBackgroundTapped(sender:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        backgroundView.addGestureRecognizer(tapGesture)
    }
    
    @objc func onBackgroundTapped(sender: UITapGestureRecognizer){
        self.dismissMenu(animated: self.animated)
    }
    
    /// Done button
    fileprivate func setDoneButton() {
        let doneTitle = (self.rightBarButtonTitle != nil) ? self.rightBarButtonTitle! : doneButtonTitle
        let doneButton = UIBarButtonItem(title: doneTitle, style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
    }
    
    @objc func doneButtonTapped() {
        self.dismissMenu(animated: self.animated)
    }
    
    /// cancel button
    fileprivate func setCancelButton() {
        let cancelTitle = (self.leftBarButtonTitle != nil) ? self.leftBarButtonTitle! : cancelButtonTitle
        let cancelButton = UIBarButtonItem(title: cancelTitle, style: .plain, target: self, action: #selector(doneButtonTapped))
        navigationItem.leftBarButtonItem = cancelButton
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    public func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return !showDoneButton()
    }
    
    // MARK: - UIGestureRecognizerDelegate
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view?.isDescendant(of: tableView!))! { return false }
        return true
    }
    
}

// MARK:- Public
extension RSSelectionMenu {
    
    /// Set selected items and selection event
    public func setSelectedItems(items: DataSource<T>, maxSelected: UInt? = nil, onDidSelectRow delegate: @escaping UITableViewCellSelection<T>) {
        let maxLimit = maxSelected ?? maxSelectionLimit
        self.tableView?.setSelectedItems(items: items, maxSelected: maxLimit, onDidSelectRow: delegate)
    }
    
    /// First row type and selection
    public func addFirstRowAs(rowType: FirstRowType, showSelected: Bool, onDidSelectFirstRow completion: @escaping FirstRowSelection) {
        self.tableView?.addFirstRowAs(rowType: rowType, showSelected: showSelected, onDidSelectFirstRow: completion)
    }
    
    /// Searchbar
    public func showSearchBar(onTextDidSearch completion: @escaping UISearchBarResult<T>) {
        self.showSearchBar(withPlaceHolder: defaultPlaceHolder, barTintColor: defaultSearchBarTintColor, onTextDidSearch: completion)
    }
    
    public func showSearchBar(withPlaceHolder: String, barTintColor: UIColor, onTextDidSearch completion: @escaping UISearchBarResult<T>) {
        self.tableView?.addSearchBar(placeHolder: withPlaceHolder, barTintColor: barTintColor, completion: completion)
    }
    
    /// Navigationbar title and color
    public func setNavigationBar(title: String, attributes:[NSAttributedString.Key: Any]? = nil, barTintColor: UIColor? = nil, tintColor: UIColor? = nil) {
        self.navigationBarTheme = NavigationBarTheme(title: title, titleAttributes: attributes, tintColor: tintColor, barTintColor: barTintColor)
    }
    
    /// Empty Data Label
    public func showEmptyDataLabel(text: String = defaultEmptyDataString, attributes: [NSAttributedString.Key: Any]? = nil) {
        self.tableView?.showEmptyDataLabel(text: text, attributes: attributes)
    }
    
    /// Show
    public func show(from: UIViewController, animated: Bool = true) {
        self.show(style: .present, from: from, animated: animated)
    }
    
    public func show(style: PresentationStyle, from: UIViewController, animated: Bool = true) {
        self.showMenu(with: style, from: from, animated: animated)
    }
    
    /// dismiss
    //This variation is necessary because instance variables cannot be used as default parameter values
    public func dismissMenu() {
        self.dismissMenu(animated: nil)
    }
    
    public func dismissMenu(animated: Bool?) {
        self.dismissed = true
        DispatchQueue.main.async { [weak self] in
            // perform on dimiss operations
            self?.menuWillDismiss()
            
            switch self?.menuPresentationStyle {
            case .push?:
                self?.navigationController?.popViewController(animated: (animated ?? self?.animated)!)
            case .present?, .popover?, .formSheet?, .alert?, .actionSheet?:
               self?.dismiss(animated: (animated ?? self?.animated)!, completion: nil)
            case .none:
                break
            }
            
            self?.menuDidDismiss()
        }
    }
    
    @available(*, unavailable, renamed: "dismissMenu(animated:)")
    public func dismiss(animated: Bool? = true) {}
}

//MARK:- Private
extension RSSelectionMenu {

    // check if show done button
    fileprivate func showDoneButton() -> Bool {
        switch menuPresentationStyle {
        case .present, .push:
            return (tableView?.selectionStyle == .multiple || !self.dismissAutomatically)
        default:
            return false
        }
    }
    
    // check if show cancel button
    fileprivate func showCancelButton() -> Bool {
        if case .present = menuPresentationStyle {
            return tableView?.selectionStyle == .single && self.dismissAutomatically
        }
        return false
    }
    
    // perform operation before dismissal
    fileprivate func menuWillDismiss() {
        
        // dismiss search
        if let searchBar = self.tableView?.searchControllerDelegate?.searchBar {
            if searchBar.isFirstResponder { searchBar.resignFirstResponder() }
        }
        
        // on menu will dismiss
        if let willDismissHandler = self.onWillDismiss {
            willDismissHandler(self.tableView?.selectionDelegate?.selectedItems ?? [])
        }
    }
    
    // perform operation after dismissal
    fileprivate func menuDidDismiss() {
        
        if let didDsmissHandler = self.onDidDismiss {
            didDsmissHandler()
        }
    }
    
    // perform operation on back button tap
    fileprivate func backButtonTap() {
        
        if let backButtonTapHandler = self.onBackButtonTapped {
            backButtonTapHandler()
        }
    }
    
    // show
    fileprivate func showMenu(with: PresentationStyle, from: UIViewController, animated: Bool) {
        parentController = from
        menuPresentationStyle = with
        
        if case .push = with {
            from.navigationController?.pushViewController(self, animated: animated)
            return
        }
        
        var tobePresentController: UIViewController = self
        if case .present = with {
            tobePresentController = UINavigationController(rootViewController: self)
        }
        else if case let .popover(sourceView, size) = with {
            tobePresentController = UINavigationController(rootViewController: self)
            tobePresentController.modalPresentationStyle = .popover
            if size != nil { tobePresentController.preferredContentSize = size! }
            
            let popover = tobePresentController.popoverPresentationController!
            popover.delegate = self
            popover.permittedArrowDirections = .any
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        else if case .formSheet = with {
            tobePresentController.modalPresentationStyle = .overCurrentContext
            tobePresentController.modalTransitionStyle = .crossDissolve
        }
        else if case let .alert(title, action, height) = with {
            tobePresentController = getAlertViewController(style: .alert, title: title, action: action, height: height)
            tobePresentController.setValue(self, forKey: contentViewController)
        }
        else if case let .actionSheet(title, action, height) = with {
            tobePresentController = getAlertViewController(style: .actionSheet, title: title, action: action, height: height)
            tobePresentController.setValue(self, forKey: contentViewController)
            
            // present as popover for iPad
            if let popoverController = tobePresentController.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.permittedArrowDirections = []
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            }
        }
        
        from.present(tobePresentController, animated: animated, completion: nil)
    }
    
    // get alert controller
    fileprivate func getAlertViewController(style: UIAlertController.Style, title: String?, action: String?, height: Double?) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: style)
        
        let actionTitle = action ?? doneButtonTitle
        let doneAction = UIAlertAction(title: actionTitle, style: .cancel) { [weak self] (doneButton) in
            self?.menuWillDismiss()
            self?.menuDidDismiss()
        }
        
        // add done action
        if (tableView?.selectionStyle == .multiple || !self.dismissAutomatically)  {
            alertController.addAction(doneAction)
        }
        
        let viewHeight = height ?? 350
        alertController.preferredContentSize.height = CGFloat(viewHeight)
        self.preferredContentSize.height = alertController.preferredContentSize.height
        return alertController
    }
    
    // navigation bar
    fileprivate func setNavigationBarTheme() {
        guard let navigationBar = self.navigationBar else { return }
        
        guard let theme = self.navigationBarTheme else {
            
            // hide navigationbar for popover, if no title present
            if case .popover = self.menuPresentationStyle {
                navigationBar.isHidden = true
            }
            
            // check for present style
            else if case .present = self.menuPresentationStyle, let parentNavigationBar = self.parentController?.navigationController?.navigationBar {
                
                navigationBar.titleTextAttributes = parentNavigationBar.titleTextAttributes
                navigationBar.barTintColor = parentNavigationBar.barTintColor
                navigationBar.tintColor = parentNavigationBar.tintColor
            }
            return
        }
        
        navigationItem.title = theme.title
        navigationBar.titleTextAttributes = theme.titleAttributes
        navigationBar.barTintColor = theme.barTintColor
        navigationBar.tintColor = theme.tintColor
    }
}
