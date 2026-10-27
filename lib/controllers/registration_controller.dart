import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firebase_service.dart';
import '../models/user_account.dart';

enum RegistrationStatus { idle, loading, success, error }

/// Control: RegistrationController
/// Merealisasikan UC-01 Register Account.
///
/// Urutan method mengikuti persis Sequence Diagram UC-01:
/// register() -> validateRegistrationData() -> createAccount()
/// -> storeAccountData() -> showRegistrationConfirmation()
/// (atau showValidationError() pada Exception Flow).
class RegistrationController extends ChangeNotifier {
  RegistrationController({FirebaseService? firebaseService})
      : _firebase = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebase;

  RegistrationStatus status = RegistrationStatus.idle;
  String? errorMessage;

  /// register(role, personalData) — dipanggil dari RegisterPage
  /// saat Pengguna menekan submitRegistrationForm().
  Future<bool> register({
    required UserRole role,
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    status = RegistrationStatus.loading;
    errorMessage = null;
    notifyListeners();

    // validateRegistrationData()
    final validationError = _validateRegistrationData(
      fullName: fullName,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (validationError != null) {
      // Exception Flow: Data registrasi tidak valid.
      status = RegistrationStatus.error;
      errorMessage = validationError;
      notifyListeners();
      return false;
    }

    try {
      // createAccount(role, personalData)
      final credential = await _firebase.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final account = UserAccount.create(
        uid: uid,
        email: email,
        fullName: fullName,
        role: role,
      );

      // storeAccountData()
      await _firebase.usersCollection.doc(uid).set(account.toMap());

      // showRegistrationConfirmation()
      status = RegistrationStatus.success;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      status = RegistrationStatus.error;
      errorMessage = _mapFirebaseError(e);
      notifyListeners();
      return false;
    } catch (_) {
      status = RegistrationStatus.error;
      errorMessage = 'Registrasi gagal. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
  }

  /// cancelRegistration() — Alternative Flow pada UC-01.
  void cancelRegistration() {
    status = RegistrationStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  String? _validateRegistrationData({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (fullName.trim().isEmpty) return 'Nama lengkap wajib diisi.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Format email tidak valid.';
    }
    if (password.length < 8) {
      return 'Kata sandi minimal 8 karakter.';
    }
    if (password != confirmPassword) {
      return 'Konfirmasi kata sandi tidak sesuai.';
    }
    return null;
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      default:
        return 'Registrasi gagal: ${e.message ?? e.code}';
    }
  }
}
