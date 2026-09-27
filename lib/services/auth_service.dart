import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_initializer.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignInInitializer? googleSignInInitializer,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignInInitializer =
           googleSignInInitializer ?? GoogleSignInInitializer();

  final FirebaseAuth _auth;
  final GoogleSignInInitializer _googleSignInInitializer;

  // Stream of auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google (v7 API)
  Future<UserCredential> signInWithGoogle() async {
    await _googleSignInInitializer.ensureInitialized();

    // Trigger the interactive Google Sign-In flow
    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate();

    // Obtain the idToken from the account's authentication data
    final GoogleSignInAuthentication googleAuth = account.authentication;

    // Create a Firebase OAuth credential from the Google ID token
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: null,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    return await _auth.signInWithCredential(credential);
  }

  // Sign out (both Firebase and Google)
  Future<void> signOut() async {
    await _googleSignInInitializer.ensureInitialized();
    await Future.wait([_auth.signOut(), GoogleSignIn.instance.signOut()]);
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
