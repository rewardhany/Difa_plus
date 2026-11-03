/// Aktor Sekunder: Maps Service
/// Dipakai pada UC-05 Show Campus Maps (penyedia data denah kampus).
///
/// Untuk sekarang datanya masih DATA CONTOH di bawah. Ganti isi
/// _seedCampusData dengan hasil survei kampus kalian sendiri
/// (nama gedung, posisi, ada ramp/lift/toilet difabel atau tidak).
/// Nanti bisa dipindah ke Firestore tanpa mengubah Controller,
/// karena kontraknya (requestMapData) sudah sama dengan sequence diagram.
class MapsService {
  MapsService({this.simulateFailure = false});

  /// Set true untuk menguji Exception Flow "Data denah gagal diterima".
  final bool simulateFailure;

  /// requestMapData() pada sequence diagram UC-05.
  /// Mengembalikan null kalau data gagal diterima.
  Future<Map<String, dynamic>?> requestMapData() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (simulateFailure) return null;
    return _seedCampusData;
  }

  // DATA CONTOH — x dan y adalah posisi relatif (0.0 - 1.0) di denah.
  static const Map<String, dynamic> _seedCampusData = {
    'locations': [
      {
        'id': 'gerbang_utama',
        'name': 'Gerbang Utama',
        'building': 'Area Depan',
        'floor': 1,
        'x': 0.50,
        'y': 0.92,
        'audioDescription':
            'Gerbang Utama kampus, titik awal navigasi. Jalur masuk datar tanpa tangga.',
        'hasRamp': true,
      },
      {
        'id': 'gedung_a',
        'name': 'Gedung A',
        'building': 'Gedung A',
        'floor': 1,
        'x': 0.20,
        'y': 0.45,
        'audioDescription':
            'Gedung A, lantai 1, di sisi kiri dari gerbang utama. Tersedia ramp dan lift.',
        'hasRamp': true,
        'hasLift': true,
        'hasAccessibleToilet': true,
      },
      {
        'id': 'gedung_b',
        'name': 'Gedung B',
        'building': 'Gedung B',
        'floor': 1,
        'x': 0.80,
        'y': 0.45,
        'audioDescription':
            'Gedung B, lantai 1, di sisi kanan dari gerbang utama. Tersedia ramp, tanpa lift.',
        'hasRamp': true,
      },
      {
        'id': 'lab_komputer',
        'name': 'Lab Komputer',
        'building': 'Gedung B',
        'floor': 2,
        'x': 0.85,
        'y': 0.15,
        'audioDescription':
            'Lab Komputer, lantai 2 Gedung B. Hanya bisa diakses lewat tangga.',
      },
      {
        'id': 'perpustakaan',
        'name': 'Perpustakaan',
        'building': 'Perpustakaan',
        'floor': 1,
        'x': 0.50,
        'y': 0.20,
        'audioDescription':
            'Perpustakaan, di bagian belakang kampus. Tersedia ramp, lift, dan toilet difabel.',
        'hasRamp': true,
        'hasLift': true,
        'hasAccessibleToilet': true,
      },
      {
        'id': 'kantin',
        'name': 'Kantin',
        'building': 'Area Tengah',
        'floor': 1,
        'x': 0.50,
        'y': 0.58,
        'audioDescription':
            'Kantin, di area tengah kampus. Lantai datar tanpa tangga.',
        'hasRamp': true,
      },
      {
        'id': 'ruang_uld',
        'name': 'Ruang ULD',
        'building': 'Gedung A',
        'floor': 1,
        'x': 0.10,
        'y': 0.65,
        'audioDescription':
            'Ruang Unit Layanan Disabilitas, lantai 1 Gedung A, dekat pintu masuk gedung.',
        'hasRamp': true,
        'hasLift': true,
      },
      {
        'id': 'toilet_difabel_a',
        'name': 'Toilet Difabel A',
        'building': 'Gedung A',
        'floor': 1,
        'x': 0.30,
        'y': 0.62,
        'audioDescription':
            'Toilet difabel Gedung A, lantai 1, dekat Ruang ULD. Pintu lebar dan tanpa tangga.',
        'hasRamp': true,
        'hasAccessibleToilet': true,
      },
    ],
  };
}
