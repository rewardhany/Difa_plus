import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firebase_service.dart';

enum AccountSaveStatus { idle, saving, success, error }

/// Control: AccountController
/// Dipakai halaman Lengkapi / Edit Profil. Mengurus data akun yang tidak
/// termasuk profil disabilitas: nama, no. telepon, dan pembuatan password
/// untuk akun yang daftar lewat Google (menautkan login email/password).
class AccountController extends ChangeNotifier {
  AccountController({FirebaseService? firebaseService})
      : _firebase = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebase;

  AccountSaveStatus status = AccountSaveStatus.idle;
  String? errorMessage;

  /// Error per kolom. Kunci: name, phone, password, confirm.
  final Map<String, String> fieldErrors = {};

  /// true jika nama dan telepon sudah tersimpan (walau password gagal),
  /// supaya halaman tetap memuat ulang data akun.
  bool detailsSaved = false;

  void reset() {
    status = AccountSaveStatus.idle;
    errorMessage = null;
    detailsSaved = false;
    fieldErrors.clear();
  }

  void clearFieldError(String key) {
    if (fieldErrors.remove(key) != null) notifyListeners();
  }

  /// Memeriksa isian. Password bersifat opsional, tapi kalau diisi harus
  /// valid (minimal 8 karakter dan sama dengan konfirmasinya).
  bool validate({
    required String fullName,
    required String phone,
    String password = '',
    String confirm = '',
  }) {
    fieldErrors.clear();

    if (fullName.trim().isEmpty) {
      fieldErrors['name'] = 'Nama lengkap wajib diisi.';
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.trim().isEmpty) {
      fieldErrors['phone'] = 'No. telepon wajib diisi.';
    } else if (digits.length < 8) {
      fieldErrors['phone'] = 'No. telepon tidak valid (minimal 8 angka).';
    }

    if (password.isNotEmpty || confirm.isNotEmpty) {
      if (password.isEmpty) {
        fieldErrors['password'] = 'Password wajib diisi.';
      } else if (password.length < 8) {
        fieldErrors['password'] = 'Password minimal 8 karakter.';
      }
      if (confirm.isEmpty) {
        fieldErrors['confirm'] = 'Konfirmasi password wajib diisi.';
      } else if (password != confirm) {
        fieldErrors['confirm'] = 'Konfirmasi password tidak sesuai.';
      }
    }

    notifyListeners();
    return fieldErrors.isEmpty;
  }

  /// Menyimpan nama + no. telepon ke Firestore, lalu (kalau [newPassword]
  /// diisi) menautkan password ke akun Google agar bisa login dengan email.
  Future<bool> save({
    required String uid,
    required String fullName,
    required String phone,
    String newPassword = '',
  }) async {
    status = AccountSaveStatus.saving;
    errorMessage = null;
    detailsSaved = false;
    notifyListeners();

    try {
      await _firebase.usersCollection.doc(uid).set(
        {'fullName': fullName.trim(), 'phone': phone.trim()},
        SetOptions(merge: true),
      );
      detailsSaved = true;

      if (newPassword.isNotEmpty) {
        final user = _firebase.auth.currentUser;
        final email = user?.email;
        if (user == null || email == null) {
          throw FirebaseAuthException(code: 'no-email');
        }
        await user.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: newPassword),
        );
      }

      status = AccountSaveStatus.success;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      status = AccountSaveStatus.error;
      errorMessage = (detailsSaved ? 'Data profil tersimpan, tetapi password belum bisa diatur. ' : '') +
          _mapError(e);
      notifyListeners();
      return false;
    } catch (_) {
      status = AccountSaveStatus.error;
      errorMessage = 'Gagal menyimpan profil. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Demi keamanan, keluar lalu masuk lagi dengan Google, kemudian atur password.';
      case 'provider-already-linked':
        return 'Akun ini sudah punya password.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'Email ini sudah dipakai akun lain.';
      case 'no-email':
        return 'Akun ini tidak punya email.';
      default:
        return e.message ?? e.code;
    }
  }
}
