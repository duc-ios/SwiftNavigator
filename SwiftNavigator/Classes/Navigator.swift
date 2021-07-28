//
//  Navigator.swift
//
//  Created by Duc Nguyen on 5/9/2021.
//  Copyright © 2021 Duc Nguyen. All rights reserved.
//

import Foundation
import UIKit
import RxCocoa
import RxSwift
import NSObject_Rx

func print(_ objects: Any...) {
    #if DEBUG
    for object in objects {
        Swift.print(object)
    }
    #endif
}

func print(_ object: Any) {
    #if DEBUG
    Swift.print(object)
    #endif
}

public protocol SceneProtocol {
    var scene: UIViewController { get }
    var sceneWithNav: UINavigationController { get }
}

public final class Navigator {
    
    enum SceneError: Error, LocalizedError {
        case noNavigationControllerFound
        case sceneNotInStack
        
        var errorDescription: String? {
            switch self {
            case .noNavigationControllerFound:
                return "No navigation controller found"
            case .sceneNotInStack:
                return "Scene not in stack"
            }
        }
    }
    
    public static var window: UIWindow = {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }()
    
    public static var topNavigationController: UINavigationController? {
        if let navigationController = window.visibleViewController?.tabBarController?.navigationController {
            return navigationController
        } else if let navigationController = window.visibleViewController?.navigationController {
            return navigationController
        } else if let navigationController = window.rootViewController as? UINavigationController {
            return navigationController
        }
        return nil
    }
    
    @discardableResult
    public static func root(_ scene: SceneProtocol) -> Completable {
        start { subject in
            let scene = scene.scene
            scene.modalTransitionStyle = .crossDissolve
            window.rootViewController = scene
            subject.onCompleted()
        }
    }
    
    @discardableResult
    public static func rootWithNav(_ scene: SceneProtocol) -> Completable {
        start { subject in
            let scene = scene.sceneWithNav
            scene.modalTransitionStyle = .crossDissolve
            window.rootViewController = scene
            subject.onCompleted()
        }
    }
    
    @discardableResult
    public static func show(_ scene: SceneProtocol, style: UIModalPresentationStyle = .fullScreen, delegate: UIViewControllerTransitioningDelegate? = nil, animated: Bool = true) -> Completable {
        start { subject in
            let scene = scene.scene
            if let delegate = delegate {
                scene.modalPresentationStyle = .custom
                scene.transitioningDelegate = delegate
            } else {
                scene.modalPresentationStyle = style
            }
            window.visibleViewController?.present(scene, animated: animated, completion: {
                subject.onCompleted()
            })
        }
    }
    
    @discardableResult
    public static func showWithNav(_ scene: SceneProtocol, style: UIModalPresentationStyle = .fullScreen, delegate: UIViewControllerTransitioningDelegate? = nil, animated: Bool = true) -> Completable {
        start { subject in
            let scene = scene.scene
            let nav = UINavigationController(rootViewController: scene)
            if let delegate = delegate {
                scene.modalPresentationStyle = .custom
                scene.transitioningDelegate = delegate
            } else {
                scene.modalPresentationStyle = style
            }
            window.visibleViewController?.present(nav, animated: animated, completion: {
                subject.onCompleted()
            })
        }
    }
    
    @discardableResult
    public static func dismiss(animated: Bool = true) -> Completable {
        start { subject in
            window.visibleViewController?.dismiss(animated: animated, completion: {
                subject.onCompleted()
            })
        }
    }
    
    @discardableResult
    public static func push(_ scene: SceneProtocol, animated: Bool = true) -> Completable {
        start { _, nav in
            nav.pushViewController(scene.scene, animated: animated)
        }
    }
    
    @discardableResult
    public static func pop(animated: Bool = true) -> Completable {
        start { _, nav in
            nav.popViewController(animated: animated)
        }
    }
    
    @discardableResult
    public static func pop(until: @escaping ((UIViewController) -> Bool), animated: Bool = true, offset: Int = 0) -> Completable {
        start { subject, nav in
            var popToIdx = nav.viewControllers.firstIndex(where: { until($0) })
            popToIdx? += offset
            if let popToIdx = popToIdx, (0..<nav.viewControllers.count).contains(popToIdx) {
                nav.popToViewController(nav.viewControllers[popToIdx], animated: animated)
            } else {
                subject.onError(SceneError.sceneNotInStack)
            }
        }
    }
    
    @discardableResult
    public static func popToRoot(animated: Bool = true) -> Completable {
        start { _, nav in
            nav.popToRootViewController(animated: animated)
        }
    }
    
    @discardableResult
    public static func replace(_ scene: SceneProtocol, animated: Bool = true) -> Completable {
        start { _, nav in
            let scene = scene.scene
            var viewControllers = nav.viewControllers
            viewControllers[max(0, viewControllers.count-1)] = scene
            nav.setViewControllers(viewControllers, animated: animated)
        }
    }
    
    static private func start(handler: ((PublishSubject<Void>) -> Void)?) -> Completable {
        let subject = PublishSubject<Void>()
        handler?(subject)
        return subject
            .asObservable()
            .take(1)
            .ignoreElements()
            .asCompletable()
    }
    
    static private func start(handler: ((PublishSubject<Void>, UINavigationController) -> Void)?) -> Completable {
        start { subject in
            guard let nav = topNavigationController else {
                subject.onError(SceneError.noNavigationControllerFound)
                return
            }
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                subject.onCompleted()
            }
            handler?(subject, nav)
            CATransaction.commit()
        }
    }
}

public extension Completable {
    func void() -> Observable<Void> {
        asObservable().do(onError: { print("Navigator error: \($0)") },
                          onCompleted: { print("Navigator completed!") },
                          onSubscribe: { print("Navigator started!") },
                          onDispose: { print("Navigator disposed!") })
            .map { _ in }
    }
}

public extension UIWindow {
    var visibleViewController: UIViewController? {
        return UIWindow.getVisibleViewControllerFrom(self.rootViewController)
    }
    
    static func getVisibleViewControllerFrom(_ vc: UIViewController?) -> UIViewController? {
        if let presentedViewController = vc?.presentedViewController, !presentedViewController.isBeingDismissed {
            return UIWindow.getVisibleViewControllerFrom(presentedViewController)
        } else if let nc = vc as? UINavigationController {
            return UIWindow.getVisibleViewControllerFrom(nc.topViewController)
        } else if let tc = vc as? UITabBarController {
            return UIWindow.getVisibleViewControllerFrom(tc.selectedViewController)
        } else {
            return vc
        }
    }
}
