import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pembungkus akses ke Firebase Auth & Firestore.
///
/// Semua Controller mengakses Firebase lewat kelas ini, bukan
/// memanggil FirebaseAuth.instance / FirebaseFirestore.instance
/// langsung — supaya gampang di-mock saat unit test nanti.
class FirebaseService {
  FirebaseService._internal();
  static final FirebaseService instance = FirebaseService._internal();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get disabilityProfilesCollection =>
      firestore.collection('disability_profiles');

  String? get currentUid => auth.currentUser?.uid;
}
