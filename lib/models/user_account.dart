/// Entity: UserAccount
/// Dipakai pada UC-01 (Register Account) dan UC-02 (Login).
///
/// Merepresentasikan akun pengguna Difa+ beserta peran dan data pribadinya.
/// Peran menentukan actor mana yang dipakai di use case lain
/// (Mahasiswa vs Pendamping vs ULD).
library;

enum UserRole { mahasiswa, pendamping, uld }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.mahasiswa:
        return 'Mahasiswa';
      case UserRole.pendamping:
        return 'Pendamping';
      case UserRole.uld:
        return 'ULD';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.mahasiswa,
    );
  }
}

class UserAccount {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;

  const UserAccount({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  /// createAccount() pada sequence diagram UC-01:
  /// dipanggil oleh RegistrationController setelah data tervalidasi.
  factory UserAccount.create({
    required String uid,
    required String email,
    required String fullName,
    required UserRole role,
  }) {
    return UserAccount(
      uid: uid,
      email: email,
      fullName: fullName,
      role: role,
      createdAt: DateTime.now(),
    );
  }

  factory UserAccount.fromMap(String uid, Map<String, dynamic> map) {
    return UserAccount(
      uid: uid,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String? ?? 'mahasiswa'),
      createdAt: (map['createdAt'] is DateTime)
          ? map['createdAt'] as DateTime
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  /// storeAccountData() pada sequence diagram UC-01.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
