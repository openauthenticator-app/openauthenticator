import AuthenticationServices
import Flutter
import UIKit
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, ASWebAuthenticationPresentationContextProviding {
  private var webAuthenticationSession: ASWebAuthenticationSession?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(
      name: "app.openauthenticator.webauth",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler(handleWebAuthenticationMethodCall)
  }

  private func handleWebAuthenticationMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "authenticate" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard webAuthenticationSession == nil else {
      result(FlutterError(code: "already_running", message: "A web authentication session is already running.", details: nil))
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let urlString = arguments["url"] as? String,
      let url = URL(string: urlString),
      let callbackUrlScheme = arguments["callbackUrlScheme"] as? String,
      !callbackUrlScheme.isEmpty
    else {
      result(FlutterError(code: "invalid_arguments", message: "Expected non-empty url and callbackUrlScheme arguments.", details: nil))
      return
    }
    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackUrlScheme) { [weak self] callbackURL, _ in
      self?.webAuthenticationSession = nil
      if let callbackURL {
        AppLinks.shared.handleLink(url: callbackURL)
      }
    }
    session.presentationContextProvider = self
    webAuthenticationSession = session
    if session.start() {
      result(nil)
    } else {
      webAuthenticationSession = nil
      result(FlutterError(code: "launch_failed", message: "Unable to start the web authentication session.", details: nil))
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window {
      return window
    }

    if let windowScene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }),
       let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
      return keyWindow
    }

    return ASPresentationAnchor()
  }
}
