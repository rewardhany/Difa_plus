/// Entity: SessionToken
/// Dipakai pada UC-02 (Login).
///
/// Merepresentasikan sesi aktif pengguna setelah autentikasi berhasil.
/// Firebase Auth sebenarnya sudah mengelola token secara internal,
/// kelas ini membungkusnya supaya tetap terlihat sebagai Entity yang
/// eksplisit, sesuai yang dimodelkan pada Sequence Diagram UC-02.
library;

class SessionToken {
  final String uid;
  final String idToken;
  final DateTime issuedAt;

  const SessionToken({
    required this.uid,
    required this.idToken,
    required this.issuedAt,
  });

  /// createUserSessionToken() pada sequence diagram UC-02.
  factory SessionToken.issue({required String uid, required String idToken}) {
    return SessionToken(
      uid: uid,
      idToken: idToken,
      issuedAt: DateTime.now(),
    );
  }

  bool get isValid => idToken.isNotEmpty;
}
