import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  // =========================
  // EMAIL / PASSWORD SIGN UP
  // =========================
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // =========================
  // EMAIL / PASSWORD LOGIN
  // =========================
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // =========================
  // GOOGLE SIGN-IN
  // =========================
  Future<UserCredential> signInWithGoogle() async {
    // WEB
    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();

      return await _auth.signInWithPopup(provider);
    }

    // ANDROID / IOS
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // =========================
  // SEND EMAIL VERIFICATION
  // =========================
  Future<void> sendVerificationEmail() async {
    final User? user = _auth.currentUser;

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // =========================
  // LOGOUT
  // =========================
  Future<void> logout() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore Google sign-out errors
      }
    }

    await _auth.signOut();
  }

  // =========================
  // PASSWORD RESET
  // =========================
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // =========================
  // CURRENT USER
  // =========================
  User? get currentUser => _auth.currentUser;

  // =========================
  // AUTH STATE
  // =========================
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
