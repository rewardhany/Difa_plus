import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/services/firebase_service.dart';
import '../core/theme/accessible_theme.dart';
import '../core/theme/app_theme.dart';
import '../models/disability_profile.dart';

enum AccessibilityLoadStatus { idle, loading, loaded, error }

/// Control: AccessibilityController
/// Merealisasikan UC-04 Load Accessibility Profile.
///
/// Ini jantung dari konsep UI adaptif Difa+: method
/// loadAccessibilityProfile() dipanggil tiap kali sesi dimulai
/// (dipanggil dari UC-02 Login lewat <<include>>), lalu menentukan
/// apakah menampilkan Home Screen yang sudah diadaptasi (profil ada
/// isinya) atau mengarahkan mahasiswa ke UC-03 Set Disability Profile
/// (profil masih kosong) — persis sesuai decision "Status Profil
/// Disabilitas?" pada Activity Diagram UC-04.
class AccessibilityController extends ChangeNotifier {
  AccessibilityController({FirebaseService? firebaseService})
      : _firebase = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebase;

  AccessibilityLoadStatus status = AccessibilityLoadStatus.idle;
  DisabilityProfile? profile;
  ThemeData currentTheme = AppTheme.base;

  /// Dibaca oleh Page untuk tahu harus redirect ke Set Disability
  /// Profile atau tidak (guard [Kosong, Bukan Mahasiswa] pada
  /// Activity Diagram UC-04).
  bool get needsProfileSetup =>
      status == AccessibilityLoadStatus.loaded &&
      (profile == null || profile!.isEmpty);

  /// readDisabilityProfile() -> pencarian profil berhasil?
  /// -> applyAccessibilityConfiguration() / applyStandardView()
  Future<void> loadAccessibilityProfile(String uid) async {
    status = AccessibilityLoadStatus.loading;
    notifyListeners();

    try {
      final doc = await _firebase.disabilityProfilesCollection.doc(uid).get();

      if (doc.exists) {
        profile = DisabilityProfile.fromMap(uid, doc.data()!);
      } else {
        profile = DisabilityProfile.empty(uid);
      }

      // applyAccessibilityConfiguration() — UI menyesuaikan tema
      // berdasarkan kategori disabilitas yang tersimpan.
      currentTheme = AccessibleTheme.resolve(profile!.categories);

      status = AccessibilityLoadStatus.loaded;
      notifyListeners();
    } catch (_) {
      // displayLoadFailureNotification() -> applyStandardView()
      // Sistem tetap bisa dipakai dengan tampilan standar walau
      // gagal memuat profil, bukan mem-block pengguna total.
      profile = null;
      currentTheme = AppTheme.base;
      status = AccessibilityLoadStatus.error;
      notifyListeners();
    }
  }

  void reset() {
    profile = null;
    currentTheme = AppTheme.base;
    status = AccessibilityLoadStatus.idle;
    notifyListeners();
  }
}
