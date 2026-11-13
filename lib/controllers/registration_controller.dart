import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firebase_service.dart';
import '../models/disability_profile.dart';
import '../models/user_account.dart';
import '../services_external/database_kampus_service.dart';

enum RegistrationStatus { idle, loading, success, error }

/// Control: RegistrationController
/// Merealisasikan UC-01 Register Account.
///
/// Urutan method mengikuti Sequence Diagram UC-01:
/// register() -> validateRegistrationData() -> createAccount()
/// -> storeAccountData() -> showRegistrationConfirmation()
/// (atau showValidationError() pada Exception Flow).
///
/// Semua kolom WAJIB diisi (nama, email, no. telepon, password,
/// konfirmasi password). Khusus Mahasiswa, jenis disabilitas juga wajib
/// dan langsung disimpan sebagai profil disabilitas saat daftar.
class RegistrationController extends ChangeNotifier {
  RegistrationController({
    FirebaseService? firebaseService,
    DatabaseKampusService? databaseKampusService,
  })  : _firebase = firebaseService ?? FirebaseService.instance,
        _databaseKampus = databaseKampusService ?? DatabaseKampusService();

  final FirebaseService _firebase;
  final DatabaseKampusService _databaseKampus;

  RegistrationStatus status = RegistrationStatus.idle;

  /// Pesan error umum (mis. dari Firebase). Error per kolom ada di [fieldErrors].
  String? errorMessage;

  /// Error per kolom. Kunci: name, email, phone, password, confirm, categories.
  final Map<String, String> fieldErrors = {};

  /// Cadangan: pilihan jenis disabilitas yang gagal tersimpan saat daftar,
  /// dipakai sebagai pilihan awal di halaman Atur Profil.
  List<DisabilityCategory> pendingCategories = [];

  void clearFieldError(String key) {
    if (fieldErrors.remove(key) != null) notifyListeners();
  }

  void clearAllErrors() {
    if (fieldErrors.isNotEmpty || errorMessage != null) {
      fieldErrors.clear();
      errorMessage = null;
      notifyListeners();
    }
  }

  /// register(role, personalData) — dipanggil dari RegisterPage
  /// saat Pengguna menekan submitRegistrationForm().
  Future<bool> register({
    required UserRole role,
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    List<DisabilityCategory> categories = const [],
  }) async {
    errorMessage = null;
    fieldErrors.clear();

    // validateRegistrationData()
    final errors = _validateRegistrationData(
      role: role,
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
      categories: categories,
    );

    if (errors.isNotEmpty) {
      // Exception Flow: Data registrasi tidak valid.
      fieldErrors.addAll(errors);
      status = RegistrationStatus.idle;
      notifyListeners();
      return false;
    }

    status = RegistrationStatus.loading;
    notifyListeners();

    try {
      // createAccount(role, personalData)
      final credential = await _firebase.auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final account = UserAccount.create(
        uid: uid,
        email: email.trim(),
        fullName: fullName.trim(),
        role: role,
        phone: phone.trim(),
      );

      // storeAccountData()
      await _firebase.usersCollection.doc(uid).set(account.toMap());

      // Mahasiswa: simpan profil disabilitas sekaligus (UC-03 / UC-11).
      pendingCategories = [];
      if (role == UserRole.mahasiswa && categories.isNotEmpty) {
        try {
          final data = DisabilityProfile(
            uid: uid,
            categories: categories,
            lastUpdated: DateTime.now(),
          ).toMap();
          await _firebase.disabilityProfilesCollection.doc(uid).set(data);
          await _databaseKampus.saveDisabilityData(uid, data);
        } catch (_) {
          // Akun sudah jadi; pilihan dijadikan pilihan awal di Atur Profil.
          pendingCategories = List.of(categories);
        }
      }

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
    fieldErrors.clear();
    notifyListeners();
  }

  Map<String, String> _validateRegistrationData({
    required UserRole role,
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required List<DisabilityCategory> categories,
  }) {
    final errors = <String, String>{};

    if (fullName.trim().isEmpty) {
      errors['name'] = 'Nama lengkap wajib diisi.';
    }

    if (email.trim().isEmpty) {
      errors['email'] = 'Email wajib diisi.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      errors['email'] = 'Format email tidak valid.';
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.trim().isEmpty) {
      errors['phone'] = 'No. telepon wajib diisi.';
    } else if (digits.length < 8) {
      errors['phone'] = 'No. telepon tidak valid (minimal 8 angka).';
    }

    if (password.isEmpty) {
      errors['password'] = 'Password wajib diisi.';
    } else if (password.length < 8) {
      errors['password'] = 'Password minimal 8 karakter.';
    }

    if (confirmPassword.isEmpty) {
      errors['confirm'] = 'Konfirmasi password wajib diisi.';
    } else if (password != confirmPassword) {
      errors['confirm'] = 'Konfirmasi password tidak sesuai.';
    }

    if (role == UserRole.mahasiswa && categories.isEmpty) {
      errors['categories'] = 'Pilih minimal satu jenis disabilitas.';
    }

    return errors;
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
