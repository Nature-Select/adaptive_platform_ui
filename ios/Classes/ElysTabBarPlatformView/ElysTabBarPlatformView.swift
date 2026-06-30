import Flutter
import UIKit

@available(iOS 26.0, *)
final class ElysTabBarPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let rootView: ElysLiquidBarView

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger,
        registrar: FlutterPluginRegistrar
    ) {
        channel = FlutterMethodChannel(
            name: "elys_platform_ui/tab_bar_\(viewId)",
            binaryMessenger: messenger
        )
        let loader = ElysAssetLoader(registrar: registrar)
        let config = ElysBarConfig(args: args) ?? ElysTabBarPlatformView.fallbackConfig()
        rootView = ElysLiquidBarView(config: config, assetLoader: loader)
        super.init()
        rootView.frame = frame
        rootView.onEvent = { [weak self] method, payload in
            self?.channel.invokeMethod(method, arguments: payload)
        }
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    func view() -> UIView {
        rootView
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setConfig":
            guard let config = ElysBarConfig(args: call.arguments) else {
                result(FlutterError(code: "bad_args", message: "Invalid config", details: nil))
                return
            }
            rootView.apply(config)
            result(nil)
        case "setInputActive":
            let args = call.arguments as? [String: Any]
            rootView.setInputActive((args?["active"] as? NSNumber)?.boolValue ?? false)
            result(nil)
        case "setInputText":
            let args = call.arguments as? [String: Any]
            rootView.setInputText(args?["text"] as? String ?? "")
            result(nil)
        case "focusInput":
            rootView.focusInput()
            result(nil)
        case "blurInput":
            rootView.blurInput()
            result(nil)
        case "updateInputOption":
            guard let item = ElysInputOptionConfig(dict: call.arguments as? [String: Any]) else {
                result(FlutterError(code: "bad_args", message: "Invalid option item", details: nil))
                return
            }
            rootView.updateInputOption(item)
            result(nil)
        case "getIntrinsicSize":
            result([
                "width": Double(rootView.bounds.width),
                "height": Double(rootView.intrinsicHeight())
            ])
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func fallbackConfig() -> ElysBarConfig {
        ElysBarConfig(args: [
            "leadingAction": ["id": "leading", "icon": ""],
            "tabs": [],
            "selectedTabId": "",
            "inputActive": false,
            "input": [:],
            "isDark": false
        ])!
    }
}

@available(iOS 26.0, *)
final class ElysTabBarViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let registrar: FlutterPluginRegistrar

    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.messenger = messenger
        self.registrar = registrar
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        ElysTabBarPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger,
            registrar: registrar
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
