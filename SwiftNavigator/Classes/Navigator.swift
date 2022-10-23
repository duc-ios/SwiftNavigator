//
//  Navigator.swift
//
//  Created by Duc Nguyen on 5/9/2021.
//  Copyright © 2021 Duc Nguyen. All rights reserved.
//

import Foundation
import UIKit
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
    
    public static var window: UIWindow = {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }()
    
    @discardableResult
    public static func root(_ scene: SceneProtocol, context: UIViewController? = nil) -> Completable {
        start { subject in
            let scene = scene.scene
            scene.modalTransitionStyle = .crossDissolve
            window.rootViewController = scene
            subject.onCompleted()
        }
    }
    
    @discardableResult
    public static func rootWithNav(_ scene: SceneProtocol, context: UIViewController? = nil) -> Completable {
        start { subject in
            let scene = scene.sceneWithNav
            scene.modalTransitionStyle = .crossDissolve
            window.rootViewController = scene
            subject.onCompleted()
        }
    }
    
    @discardableResult
    public static func show(_ scene: SceneProtocol, style: UIModalPresentationStyle = .fullScreen, delegate: UIViewControllerTransitioningDelegate? = nil, animated: Bool = true, context: UIViewController? = nil) -> Completable {
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
    public static func showWithNav(_ scene: SceneProtocol, style: UIModalPresentationStyle = .fullScreen, delegate: UIViewControllerTransitioningDelegate? = nil, animated: Bool = true, context: UIViewController? = nil) -> Completable {
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
    public static func dismiss(animated: Bool = true, context: UIViewController? = nil) -> Completable {
        start { subject in
            window.visibleViewController?.dismiss(animated: animated, completion: {
                subject.onCompleted()
            })
        }
    }
    
    @discardableResult
    public static func push(_ scene: SceneProtocol, animated: Bool = true, context: UIViewController? = nil) -> Completable {
        start { _, nav in
            nav.pushViewController(scene.scene, animated: animated)
        }
    }
    
    public static func canPop(context: UIViewController? = nil) -> Bool {
        ((context?.navigationController ?? window.topNavigationController)?.viewControllers.count ?? 0) > 1
    }
    
    @discardableResult
    public static func pop(animated: Bool = true, context: UIViewController? = nil) -> Completable {
        guard canPop(context: context)
        else {
            let error = "Cannot pop!"
            debugPrint(error)
            return .error(error)
        }
        return start { _, nav in
            nav.popViewController(animated: animated)
        }
    }
    
    @discardableResult
    public static func pop(until: @escaping ((UIViewController) -> Bool), animated: Bool = true, offset: Int = 0, context: UIViewController? = nil) -> Completable {
        start { subject, nav in
            var popToIdx = nav.viewControllers.firstIndex(where: { until($0) })
            popToIdx? += offset
            if let popToIdx = popToIdx, (0..<nav.viewControllers.count).contains(popToIdx) {
                nav.popToViewController(nav.viewControllers[popToIdx], animated: animated)
            } else {
                subject.onError("Scene not in stack")
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
    public static func replace(_ scene: SceneProtocol, animated: Bool = true, context: UIViewController? = nil) -> Completable {
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
    
    static private func start(handler: ((PublishSubject<Void>, UINavigationController) -> Void)?, context: UIViewController? = nil) -> Completable {
        start { subject in
            guard let nav = context?.navigationController ?? window.topNavigationController else {
                subject.onError("No navigation controller found")
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
    
    var topNavigationController: UINavigationController? {
        if let navigationController = visibleViewController?.tabBarController?.navigationController {
            return navigationController
        } else if let navigationController = visibleViewController?.navigationController {
            return navigationController
        } else if let navigationController = rootViewController as? UINavigationController {
            return navigationController
        }
        return nil
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { self }
}
