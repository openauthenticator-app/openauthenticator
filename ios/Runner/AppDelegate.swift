import AuthenticationServices
import Flutter
import SafariServices
import UIKit
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, ASWebAuthenticationPresentationContextProviding {
  private var webAuthenticationSession: Any?
  private var webAuthenticationPending = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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
    guard !webAuthenticationPending else {
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
    webAuthenticationPending = true
    if #available(iOS 12.0, *) {
      let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackUrlScheme) { [weak self] callbackURL, error in
        self?.completeWebAuthentication(callbackURL: callbackURL, error: error)
      }
      if #available(iOS 13.0, *) {
        session.presentationContextProvider = self
      }
      webAuthenticationSession = session
      if !session.start() {
        failWebAuthentication(code: "launch_failed", message: "Unable to start the web authentication session.")
        result(FlutterError(code: "launch_failed", message: "Unable to start the web authentication session.", details: nil))
      } else {
        result(nil)
      }
    } else if #available(iOS 11.0, *) {
      let session = SFAuthenticationSession(url: url, callbackURLScheme: callbackUrlScheme) { [weak self] callbackURL, error in
        self?.completeWebAuthentication(callbackURL: callbackURL, error: error)
      }
      webAuthenticationSession = session
      if !session.start() {
        failWebAuthentication(code: "launch_failed", message: "Unable to start the web authentication session.")
        result(FlutterError(code: "launch_failed", message: "Unable to start the web authentication session.", details: nil))
      } else {
        result(nil)
      }
    } else {
      failWebAuthentication(code: "unsupported_platform", message: "Web authentication requires iOS 11.0 or later.")
      result(FlutterError(code: "unsupported_platform", message: "Web authentication requires iOS 11.0 or later.", details: nil))
    }
  }

  private func completeWebAuthentication(callbackURL: URL?, error: Error?) {
    webAuthenticationPending = false
    webAuthenticationSession = nil
    if let callbackURL {
      AppLinks.shared.handleLink(url: callbackURL)
      return
    }
  }

  private func failWebAuthentication(code: String, message: String) {
    webAuthenticationPending = false
    webAuthenticationSession = nil
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window {
      return window
    }

    if #available(iOS 13.0, *) {
      if let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }),
         let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
        return keyWindow
      }
    }

    return ASPresentationAnchor()
  }
}
