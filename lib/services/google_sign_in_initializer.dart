import 'package:autodentifyr/firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Initializes the Google Sign-In singleton once, immediately before it is used.
class GoogleSignInInitializer {
  GoogleSignInInitializer({Future<void> Function()? initialize})
    : _initialize = initialize ?? _initializeGoogleSignIn;

  final Future<void> Function() _initialize;
  Future<void>? _initialization;

  Future<void> ensureInitialized() => _initialization ??= _initialize();

  static Future<void> _initializeGoogleSignIn() {
    return GoogleSignIn.instance.initialize(
      serverClientId: DefaultFirebaseOptions.googleSignInServerClientId,
    );
  }
}
