/// Entity: DisabilityProfile
/// Dipakai pada UC-03, UC-04, UC-07, UC-08, UC-11, dan UC-16.
///
/// Entity paling sering dipakai lintas use case karena jadi dasar
/// penentuan mode UI adaptif (UC-04) dan fitur yang diaktifkan
/// per kategori disabilitas.
library;

/// Lima kategori resmi berdasarkan UU No. 8/2016, dipersempit ke
/// yang relevan dengan konteks navigasi & materi kuliah kampus.
/// Catatan: Fase 1 sistem baru mengimplementasikan 3 dari 5 kategori
/// (fisik, netra, rungu/wicara) — intelektual & mental disiapkan di
/// enum ini supaya ekstensi di fase berikutnya tidak perlu migrasi data.
enum DisabilityCategory {
  netra,
  runguWicara,
  fisik,
  intelektual,
  mentalPsikososial,
}

extension DisabilityCategoryX on DisabilityCategory {
  String get label {
    switch (this) {
      case DisabilityCategory.netra:
        return 'Netra';
      case DisabilityCategory.runguWicara:
        return 'Rungu / Wicara';
      case DisabilityCategory.fisik:
        return 'Fisik';
      case DisabilityCategory.intelektual:
        return 'Intelektual';
      case DisabilityCategory.mentalPsikososial:
        return 'Mental / Psikososial';
    }
  }

  static DisabilityCategory fromString(String value) {
    return DisabilityCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => DisabilityCategory.fisik,
    );
  }
}

class DisabilityProfile {
  final String uid;
  final List<DisabilityCategory> categories;
  final DateTime lastUpdated;

  const DisabilityProfile({
    required this.uid,
    required this.categories,
    required this.lastUpdated,
  });

  bool get isEmpty => categories.isEmpty;

  bool get isNetra => categories.contains(DisabilityCategory.netra);
  bool get isRunguWicara =>
      categories.contains(DisabilityCategory.runguWicara);
  bool get isFisik => categories.contains(DisabilityCategory.fisik);

  factory DisabilityProfile.empty(String uid) {
    return DisabilityProfile(
      uid: uid,
      categories: const [],
      lastUpdated: DateTime.now(),
    );
  }

  factory DisabilityProfile.fromMap(String uid, Map<String, dynamic> map) {
    final rawCategories = (map['categories'] as List<dynamic>? ?? []);
    return DisabilityProfile(
      uid: uid,
      categories: rawCategories
          .map((c) => DisabilityCategoryX.fromString(c.toString()))
          .toList(),
      lastUpdated: DateTime.tryParse(map['lastUpdated']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// saveDisabilityData() pada sequence diagram UC-03 / UC-11.
  Map<String, dynamic> toMap() {
    return {
      'categories': categories.map((c) => c.name).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  DisabilityProfile copyWith({List<DisabilityCategory>? categories}) {
    return DisabilityProfile(
      uid: uid,
      categories: categories ?? this.categories,
      lastUpdated: DateTime.now(),
    );
  }
}
