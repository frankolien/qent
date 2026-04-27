import Flutter
import SwiftUI
import UIKit

/// Registers the Liquid Glass tab bar as a Flutter PlatformView.
/// Available on iOS 26+ only — older versions get an empty UIView so Flutter
/// can still instantiate the widget without crashing.
class LiquidTabBarFactory: NSObject, FlutterPlatformViewFactory {
    private weak var messenger: FlutterBinaryMessenger?

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        if #available(iOS 26.0, *), let messenger = messenger {
            return LiquidTabBarPlatformView(frame: frame, viewId: viewId, messenger: messenger)
        } else {
            return EmptyPlatformView(frame: frame)
        }
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Fallback for iOS < 26 — empty view, never displayed since Flutter only
/// instantiates the platform view when iOS version check passes.
class EmptyPlatformView: NSObject, FlutterPlatformView {
    private let _view: UIView
    init(frame: CGRect) {
        _view = UIView(frame: frame)
    }
    func view() -> UIView { return _view }
}

@available(iOS 26.0, *)
class LiquidTabBarPlatformView: NSObject, FlutterPlatformView {
    private let hostingController: UIHostingController<LiquidTabBarView>
    private let channel: FlutterMethodChannel
    private var swiftUIView: LiquidTabBarView

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
        let channelName = "qent.online/liquid_tab/\(viewId)"
        self.channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        // Hold a reference to the view so we can update its state from Flutter.
        var capturedSelf: LiquidTabBarPlatformView?
        let view = LiquidTabBarView(onSelect: { index in
            capturedSelf?.channel.invokeMethod("tabSelected", arguments: index)
        })
        self.swiftUIView = view
        self.hostingController = UIHostingController(rootView: view)
        self.hostingController.view.backgroundColor = .clear

        super.init()
        capturedSelf = self

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "setSelectedIndex":
                if let index = call.arguments as? Int {
                    self.swiftUIView.setSelection(index)
                    self.hostingController.rootView = self.swiftUIView
                }
                result(nil)
            case "setProfilePhotoUrl":
                let url = call.arguments as? String
                self.swiftUIView.setProfilePhotoUrl(url)
                self.hostingController.rootView = self.swiftUIView
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView {
        return hostingController.view
    }
}
