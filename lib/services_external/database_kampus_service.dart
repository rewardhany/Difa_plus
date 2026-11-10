/// Aktor Sekunder: Database Kampus
/// Dipakai pada UC-03, UC-11, UC-13, UC-15 (lihat Sequence Diagram
/// dokumen P6 — Database Kampus digambar sebagai participant «actor»,
/// bukan participant internal).
///
/// Fase 1 belum terhubung ke sistem informasi akademik kampus yang
/// sesungguhnya, jadi diimplementasikan sebagai stub yang selalu
/// berhasil. Saat integrasi nyata tersedia (mis. lewat REST API
/// SIAK), cukup ganti isi method ini — kontraknya (nama & signature
/// method) sudah dijaga sama dengan saveDisabilityData() pada
/// sequence diagram supaya tidak ada refactor di Controller.
class DatabaseKampusService {
  /// saveDisabilityData() pada sequence diagram UC-03 / UC-11 / UC-15.
  Future<bool> saveDisabilityData(String uid, Map<String, dynamic> data) async {
    // TODO(Fase 2): ganti dengan panggilan API SIAK/Database Kampus asli.
    await Future.delayed(const Duration(milliseconds: 300));
    return true; // simulasi sinkronisasi selalu berhasil di Fase 1
  }
}
