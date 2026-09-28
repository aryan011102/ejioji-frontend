import Flutter
import MusicKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleMusicBridge") {
      AppleMusicBridge.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenCaptureBridge") {
      ScreenCaptureBridge.register(with: registrar.messenger())
    }
  }
}

/// Other people's profiles and chats, kept out of screenshots and recordings
/// while one is on screen (lib/core/native/screen_capture.dart).
///
/// iOS has no API that refuses a screenshot. What it does leave out of every
/// screenshot, recording and mirror is the inside of a secure text field, the
/// kind a password is typed into. So the window's layer is moved, once, into
/// that field's content layer, and switching `isSecureTextEntry` on and off
/// then decides whether a capture can see the app. Touches are unaffected
/// (they follow views, not layers), and the field is never shown or focused.
///
/// This is undocumented, and Apple could move the layers in any release. If
/// the content layer is not there, nothing is moved and the app draws as
/// normal, unprotected. Either way the two public APIs below still work: the
/// Dart side covers the screen while a recording or mirror runs, and tells
/// whoever took a screenshot that it is not allowed.
///
/// Everything here runs on the main thread: Flutter calls method handlers
/// there, and the observers ask for the main queue.
enum ScreenCaptureBridge {
  /// Made the first time a screen asks for protection, then kept for the life
  /// of the window. Stays nil if the content layer was not found.
  private static var field: UITextField?
  private static var tried = false

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "theonebytwo/screen_capture", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "setProtected", let on = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      setProtected(on)
      result(isCaptured)
    }
    NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
    ) { _ in
      channel.invokeMethod("screenshot", arguments: nil)
    }
    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
    ) { _ in
      channel.invokeMethod("captured", arguments: isCaptured)
    }
  }

  private static var window: UIWindow? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return windows.first { $0.isKeyWindow } ?? windows.first
  }

  /// A screen recording, AirPlay or a mirrored display is running.
  private static var isCaptured: Bool {
    window?.windowScene?.screen.isCaptured ?? false
  }

  private static func setProtected(_ on: Bool) {
    if on && !tried {
      tried = true
      if let window = window { field = shield(window) }
    }
    field?.isSecureTextEntry = on
  }

  private static func shield(_ window: UIWindow) -> UITextField? {
    guard let root = window.layer.superlayer else { return nil }
    // A zero frame and no constraints, so the window's layer, once inside,
    // keeps exactly the position it has now.
    let field = UITextField(frame: .zero)
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    window.addSubview(field)
    // The secure content layer is the first sublayer before iOS 17 and the
    // last from 17 on.
    let content: CALayer?
    if #available(iOS 17.0, *) {
      content = field.layer.sublayers?.last
    } else {
      content = field.layer.sublayers?.first
    }
    guard let content = content else {
      field.removeFromSuperview()
      return nil
    }
    root.addSublayer(field.layer)
    content.addSublayer(window.layer)
    return field
  }
}

/// Apple Music's permission prompt and the Music User Token, for the connect
/// screen (lib/core/native/apple_music_kit.dart).
///
/// Here rather than in a plugin so no third-party code ever holds the token,
/// and in this file rather than its own so the Xcode project needs no edit.
/// Nothing is stored: the token goes back to Dart, which sends it to our
/// server once.
enum AppleMusicBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "theonebytwo/apple_music", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "userToken" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let developerToken = arguments["developerToken"] as? String,
        !developerToken.isEmpty
      else {
        result(FlutterError(code: "bad_arguments", message: nil, details: nil))
        return
      }
      Task { @MainActor in
        let answer = await userToken(developerToken: developerToken)
        result(answer)
      }
    }
  }

  /// A token string, or a FlutterError whose code the Dart side reads.
  private static func userToken(developerToken: String) async -> Any {
    // Refused before, or restricted by a parent or employer: iOS will not show
    // the prompt again, so say so rather than appear to do nothing.
    switch MusicAuthorization.currentStatus {
    case .denied, .restricted:
      return FlutterError(code: "denied_in_settings", message: nil, details: nil)
    default:
      break
    }
    guard await MusicAuthorization.request() == .authorized else {
      return FlutterError(code: "denied", message: nil, details: nil)
    }
    do {
      return try await MusicUserTokenProvider().userToken(
        for: developerToken, options: .ignoreCache)
    } catch let error as MusicTokenRequestError {
      // Which of Apple's reasons, as a fixed word, so the app can say what to
      // do about it. Never the error's own text.
      return FlutterError(code: "token_failed", message: nil, details: reason(error))
    } catch {
      return FlutterError(code: "token_failed", message: nil, details: "other")
    }
  }

  /// Only the cases Apple's documentation lists are named. Anything else is read
  /// by its case name, which compiles whatever this SDK's list holds.
  private static func reason(_ error: MusicTokenRequestError) -> String {
    switch error {
    case .developerTokenRequestFailed: return "developer_token"
    case .permissionDenied: return "permission_denied"
    case .privacyAcknowledgementRequired: return "privacy_acknowledgement"
    case .userTokenRequestFailed: return "user_token"
    default:
      return String(describing: error) == "userNotSignedIn" ? "not_signed_in" : "unknown"
    }
  }
}
