import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firebase_service.dart';
import '../models/session_token.dart';
import '../models/user_account.dart';

enum AuthStatus { idle, loading, authenticated, error }

/// Hasil login / daftar dengan Google.
/// - existingAccount : akun sudah terdaftar di Difa+, langsung masuk.
/// - newAccount      : akun Google baru, data akun baru dibuat.
/// - needsRole       : akun Google baru, tapi peran (Mahasiswa/Pendamping) belum dipilih.
/// - cancelled       : user menutup jendela pilih akun Google.
/// - failed          : gagal, lihat [AuthController.errorMessage].
enum GoogleAuthResult { existingAccount, newAccount, needsRole, cancelled, failed }

/// Control: AuthController
/// Merealisasikan UC-02 Login (email/password dan Google), dan dipakai
/// juga pada UC-04 (lihat tabel Ringkasan Participant: UC-04 Control =
/// AuthController, AccessibilityController).
///
/// Setelah login, halaman memanggil UC-04 lewat <<include>> (lihat
/// core/utils/auth_flow.dart).
class AuthController extends ChangeNotifier {
  AuthController({FirebaseService? firebaseService})
      : _firebase = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebase;

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;
  UserAccount? currentAccount;
  SessionToken? sessionToken;

  // ---- mode demo (hanya dipakai dari tombol demo di debug) ----
  bool _isDemo = false;
  bool _demoHasPassword = true;
  bool get isDemo => _isDemo;

  /// Apakah akun ini sudah punya password (login email/password).
  /// Akun yang daftar lewat Google awalnya belum punya password.
  bool get hasPassword {
    if (_isDemo) return _demoHasPassword;
    final user = _firebase.auth.currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  bool get isGoogleAccount {
    if (_isDemo) return !_demoHasPassword;
    final user = _firebase.auth.currentUser;
    return user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  }

  // ================================================== email + password

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

  // ================================================== Google

  /// Login / daftar dengan Google.
  ///
  /// Alur: pilih akun Google -> Firebase mengembalikan nama + email ->
  /// cek koleksi 'users'. Kalau akun sudah ada, langsung masuk. Kalau
  /// belum ada, dibuat akun baru dengan [roleIfNew]; jika [roleIfNew]
  /// null, hasilnya [GoogleAuthResult.needsRole] dan halaman harus
  /// menanyakan peran lalu memanggil [finishGoogleSignUp].
  ///
  /// Di web memakai popup, di Android/iOS memakai alur OAuth bawaan
  /// firebase_auth (tanpa package tambahan).
  Future<GoogleAuthResult> signInWithGoogle({UserRole? roleIfNew}) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});

      final UserCredential credential = kIsWeb
          ? await _firebase.auth.signInWithPopup(provider)
          : await _firebase.auth.signInWithProvider(provider);

      final user = credential.user!;
      final idToken = await user.getIdToken() ?? '';
      sessionToken = SessionToken.issue(uid: user.uid, idToken: idToken);

      final doc = await _firebase.usersCollection.doc(user.uid).get();
      if (doc.exists) {
        currentAccount = UserAccount.fromMap(user.uid, doc.data()!);
        status = AuthStatus.authenticated;
        notifyListeners();
        return GoogleAuthResult.existingAccount;
      }

      if (roleIfNew == null) {
        status = AuthStatus.idle;
        notifyListeners();
        return GoogleAuthResult.needsRole;
      }

      await _createGoogleAccount(user, roleIfNew);
      return GoogleAuthResult.newAccount;
    } on FirebaseAuthException catch (e) {
      if (_isCancelled(e)) {
        status = AuthStatus.idle;
        notifyListeners();
        return GoogleAuthResult.cancelled;
      }
      status = AuthStatus.error;
      errorMessage = _mapGoogleError(e);
      notifyListeners();
      return GoogleAuthResult.failed;
    } catch (_) {
      status = AuthStatus.error;
      errorMessage = 'Login dengan Google gagal. Silakan coba lagi.';
      notifyListeners();
      return GoogleAuthResult.failed;
    }
  }

  /// Dipanggil setelah [GoogleAuthResult.needsRole] dan user memilih peran.
  Future<bool> finishGoogleSignUp(UserRole role) async {
    final user = _firebase.auth.currentUser;
    if (user == null) {
      status = AuthStatus.error;
      errorMessage = 'Sesi Google berakhir. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
    try {
      await _createGoogleAccount(user, role);
      return true;
    } catch (_) {
      status = AuthStatus.error;
      errorMessage = 'Gagal menyimpan data akun. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
  }

  /// Membuat data akun dari data Google: baru nama dan email yang terisi.
  /// No. telepon, jenis disabilitas, dan password dilengkapi nanti lewat
  /// banner "Lengkapi profil" di Beranda.
  Future<void> _createGoogleAccount(User user, UserRole role) async {
    final displayName = user.displayName?.trim() ?? '';
    final account = UserAccount.create(
      uid: user.uid,
      email: user.email ?? '',
      fullName: displayName.isEmpty ? 'Pengguna' : displayName,
      role: role,
    );
    await _firebase.usersCollection.doc(user.uid).set(account.toMap());
    currentAccount = account;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  // ================================================== umum

  /// Memuat ulang data akun dari Firestore (dipanggil setelah edit profil).
  Future<void> refreshAccount() async {
    if (_isDemo) return;
    final uid = sessionToken?.uid ?? _firebase.currentUid;
    if (uid == null) return;
    try {
      await _firebase.auth.currentUser?.reload(); // update daftar provider
      final doc = await _firebase.usersCollection.doc(uid).get();
      if (doc.exists) {
        currentAccount = UserAccount.fromMap(uid, doc.data()!);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    await _firebase.auth.signOut();
    currentAccount = null;
    sessionToken = null;
    _isDemo = false;
    _demoHasPassword = true;
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  // ================================================== mode demo

  /// MODE DEMO (debug): akun contoh tanpa Firebase supaya onboarding dan
  /// banner "Lengkapi profil" bisa dicoba. [googleNew] true = belum ada
  /// password dan belum ada no. telepon, seperti akun Google baru.
  void applyDemoAccount({
    required String name,
    required UserRole role,
    bool googleNew = false,
  }) {
    _isDemo = true;
    _demoHasPassword = !googleNew;
    currentAccount = UserAccount.create(
      uid: 'demo',
      email: 'demo@gmail.com',
      fullName: name,
      role: role,
    );
    sessionToken = SessionToken.issue(uid: 'demo', idToken: 'demo');
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// MODE DEMO (debug): simpan perubahan profil hanya di memori.
  void applyDemoUpdate({String? fullName, String? phone, bool? hasPassword}) {
    if (!_isDemo) return;
    currentAccount = currentAccount?.copyWith(fullName: fullName, phone: phone);
    if (hasPassword != null) _demoHasPassword = hasPassword;
    notifyListeners();
  }

  // ================================================== pesan error

  bool _isCancelled(FirebaseAuthException e) {
    const codes = {
      'popup-closed-by-user',
      'cancelled-popup-request',
      'web-context-canceled',
      'web-context-cancelled',
      'canceled',
      'user-cancelled',
    };
    return codes.contains(e.code);
  }

  String _mapGoogleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Email ini sudah terdaftar dengan password. Masuk memakai email dan password.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah. Periksa koneksi lalu coba lagi.';
      case 'operation-not-allowed':
        return 'Login Google belum diaktifkan di Firebase (Authentication > Sign-in method).';
      case 'popup-blocked':
        return 'Popup diblokir browser. Izinkan popup lalu coba lagi.';
      default:
        return 'Login dengan Google gagal: ${e.message ?? e.code}';
    }
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
