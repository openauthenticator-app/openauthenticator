import AuthenticationServices
import Cocoa
import FlutterMacOS
import FirebaseAuth
import app_links

class MainFlutterWindow: NSWindow, ASWebAuthenticationPresentationContextProviding {
  private var webAuthenticationSession: ASWebAuthenticationSession?
  private var webAuthenticationPending = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    FlutterMethodChannel(
      name: "app.openauthenticator.webauth",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler(handleWebAuthenticationMethodCall)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
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
    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackUrlScheme) { [weak self] callbackURL, error in
      self?.completeWebAuthentication(callbackURL: callbackURL, error: error)
    }
    session.presentationContextProvider = self
    webAuthenticationSession = session
    if !session.start() {
      failWebAuthentication(code: "launch_failed", message: "Unable to start the web authentication session.")
      result(FlutterError(code: "launch_failed", message: "Unable to start the web authentication session.", details: nil))
    } else {
      result(nil)
    }
  }

  private func completeWebAuthentication(callbackURL: URL?, error: Error?) {
    webAuthenticationPending = false
    webAuthenticationSession = nil
    if let callbackURL {
      AppLinks.shared.handleLink(link: callbackURL.absoluteString)
    }
  }

  private func failWebAuthentication(code: String, message: String) {
    webAuthenticationPending = false
    webAuthenticationSession = nil
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    return self
  }
}
