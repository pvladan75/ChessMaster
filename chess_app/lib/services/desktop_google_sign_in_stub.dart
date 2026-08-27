/// The web's half of [desktop_google_sign_in.dart]: there is no desktop here.
///
/// The web build has `google_sign_in` proper, so nothing needs to fall back to
/// a loopback server it could not open anyway.
class DesktopGoogleSignIn {
  const DesktopGoogleSignIn();

  static bool get isSupported => false;
  static bool get isConfigured => false;

  Future<String> obtainIdToken({String? loginHint}) {
    throw UnsupportedError('Desktop Google sign-in is not available here.');
  }
}
