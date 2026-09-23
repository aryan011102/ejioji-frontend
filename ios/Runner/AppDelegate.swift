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
    } catch {
      // Only the kind of failure goes back, never the error's own text.
      return FlutterError(code: "token_failed", message: nil, details: nil)
    }
  }
}
