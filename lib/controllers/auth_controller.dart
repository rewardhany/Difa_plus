import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firebase_service.dart';
import '../models/session_token.dart';
import '../models/user_account.dart';

enum AuthStatus { idle, loading, authenticated, error }

/// Control: AuthController
/// Merealisasikan UC-02 Login, dan dipakai juga pada UC-04
/// (lihat tabel Ringkasan Participant: UC-04 Control = AuthController,
/// AccessibilityController).
///
/// Sequence: login() -> createUserSessionToken() -> (<<include>> UC-04
/// LoadAccessibilityProfile dijalankan oleh AccessibilityController,
/// dipanggil dari luar kelas ini — lihat ProfileFlowCoordinator
/// di pages/auth/login_page.dart).
class AuthController extends ChangeNotifier {
  AuthController({FirebaseService? firebaseService})
      : _firebase = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebase;

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;
  UserAccount? currentAccount;
  SessionToken? sessionToken;

  Future<bool> login({required String email, required String password}) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebase.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;
      final idToken = await user.getIdToken() ?? '';

      // createUserSessionToken()
      sessionToken = SessionToken.issue(uid: user.uid, idToken: idToken);

      // Mengambil data akun (bukan bagian dari sequence UC-02, tapi
      // dibutuhkan Page untuk menyapa pengguna & menentukan role).
      final doc = await _firebase.usersCollection.doc(user.uid).get();
      if (doc.exists) {
        currentAccount = UserAccount.fromMap(user.uid, doc.data()!);
      }

      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      status = AuthStatus.error;
      errorMessage = _mapFirebaseError(e);
      notifyListeners();
      return false;
    } catch (_) {
      status = AuthStatus.error;
      errorMessage = 'Login gagal. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _firebase.auth.signOut();
    currentAccount = null;
    sessionToken = null;
    status = AuthStatus.idle;
    notifyListeners();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        // Exception Flow UC-02: "Akun tidak ditemukan di database"
        return 'Akun tidak ditemukan. Periksa email atau daftar akun baru.';
      case 'wrong-password':
      case 'invalid-credential':
        // Exception Flow UC-02: "Username/Password Salah"
        return 'Email atau kata sandi salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      default:
        return 'Login gagal: ${e.message ?? e.code}';
    }
  }
}
