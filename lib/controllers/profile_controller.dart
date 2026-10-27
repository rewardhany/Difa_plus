import 'package:flutter/foundation.dart';
import '../core/services/firebase_service.dart';
import '../models/disability_profile.dart';
import '../services_external/database_kampus_service.dart';

enum ProfileSaveStatus { idle, saving, success, error }

/// Control: ProfileController
/// Merealisasikan UC-03 Set Disability Profile, dan menjalankan
/// UC-11 Store Disability Data lewat relasi <<include>>.
///
/// Sesuai catatan konvensi pada dokumen Sequence Diagram: "Nama
/// message pada UC-11 disamakan dengan UC-03" — karena itu method
/// saveDisabilityData() di bawah ini dipakai utuh untuk merealisasikan
/// kedua use case tersebut, bukan diduplikasi jadi dua method.
class ProfileController extends ChangeNotifier {
  ProfileController({
    FirebaseService? firebaseService,
    DatabaseKampusService? databaseKampusService,
  })  : _firebase = firebaseService ?? FirebaseService.instance,
        _databaseKampus = databaseKampusService ?? DatabaseKampusService();

  final FirebaseService _firebase;
  final DatabaseKampusService _databaseKampus;

  ProfileSaveStatus status = ProfileSaveStatus.idle;
  String? errorMessage;
  List<DisabilityCategory> selectedCategories = [];

  void toggleCategory(DisabilityCategory category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
    notifyListeners();
  }

  /// saveProfile() — dipanggil dari ProfilePage saat mahasiswa
  /// menekan tombol Simpan (guard [Simpan] pada Activity Diagram UC-03).
  ///
  /// Sequence: validateCategorySelection() -> encryptDisabilityData()
  /// -> UC-11 <<include>>: saveDisabilityData() ke Firestore DAN
  /// ke Database Kampus (aktor sekunder).
  Future<bool> saveProfile(String uid) async {
    status = ProfileSaveStatus.saving;
    errorMessage = null;
    notifyListeners();

    // validateCategorySelection()
    if (selectedCategories.isEmpty) {
      status = ProfileSaveStatus.error;
      errorMessage = 'Pilih minimal satu kategori disabilitas.';
      notifyListeners();
      return false;
    }

    try {
      final profile = DisabilityProfile(
        uid: uid,
        categories: selectedCategories,
        lastUpdated: DateTime.now(),
      );

      // encryptDisabilityData() — NFR Security: data kondisi disabilitas
      // harus terenkripsi. Firestore mengenkripsi data saat transit &
      // at-rest secara default; untuk field sensitif tambahan, enkripsi
      // level-aplikasi bisa ditambahkan di titik ini pada Fase 2.
      final data = profile.toMap();

      // UC-11 (<<include>>): simpan ke Firestore (internal)
      await _firebase.disabilityProfilesCollection.doc(uid).set(data);

      // UC-11 (<<include>>): saveDisabilityData() ke Database Kampus
      // (aktor sekunder). Exception Flow [sync failed] ditangani di
      // bawah tanpa membatalkan penyimpanan lokal, sesuai Activity
      // Diagram UC-15 yang memperbolehkan percobaan ulang sinkronisasi.
      final synced = await _databaseKampus.saveDisabilityData(uid, data);
      if (!synced) {
        status = ProfileSaveStatus.error;
        errorMessage =
            'Profil tersimpan, tetapi sinkronisasi ke Database Kampus gagal.';
        notifyListeners();
        return false;
      }

      status = ProfileSaveStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      status = ProfileSaveStatus.error;
      errorMessage = 'Gagal menyimpan profil. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
  }

  /// cancelEditing() — Alternative Flow pada UC-03.
  void cancelEditing(DisabilityProfile? original) {
    selectedCategories = List.of(original?.categories ?? []);
    status = ProfileSaveStatus.idle;
    notifyListeners();
  }
}
