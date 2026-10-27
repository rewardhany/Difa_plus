# Difa+ — Fase 1 (Auth + Adaptive Profile)

Implementasi UC-01 Register Account, UC-02 Login, UC-03 Set Disability
Profile, dan UC-04 Load Accessibility Profile — sesuai Use Case,
Activity Diagram, dan Sequence Diagram pada laporan RPL Kelompok 3.

## Cakupan Fase 1

| Use Case | Status |
|---|---|
| UC-01 Register Account | ✅ Implemented |
| UC-02 Login | ✅ Implemented |
| UC-03 Set Disability Profile | ✅ Implemented (3 dari 5 kategori) |
| UC-04 Load Accessibility Profile | ✅ Implemented |
| UC-05 – UC-16 | ⏳ Fase 2 dan seterusnya |

Kategori disabilitas yang sudah punya efek UI nyata di Fase 1: **netra**,
**fisik**, **rungu/wicara**. Kategori **intelektual** dan **mental/
psikososial** sudah ada di model (`DisabilityCategory`) tapi belum
ditampilkan sebagai pilihan di `ProfilePage` sampai fitur pendukungnya
(ringkasan bahasa sederhana, mode fokus) dibangun di Fase 2+.

## Setup

1. **Install Flutter SDK** (stable channel) — ikuti
   [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install).

2. **Buat project Firebase** di [console.firebase.google.com](https://console.firebase.google.com),
   aktifkan:
   - Authentication → sign-in method → Email/Password
   - Firestore Database → mulai dalam mode test (ganti rules sebelum
     deploy sungguhan — lihat bagian Firestore Rules di bawah)

3. **Hubungkan project ke Firebase:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Ini akan membuat file `lib/firebase_options.dart` secara otomatis
   (jangan ditulis manual).

4. **Install dependency:**
   ```bash
   flutter pub get
   ```

5. **Jalankan:**
   ```bash
   flutter run
   ```

## Firestore Rules (minimum, sesuaikan sebelum dipakai sungguhan)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /disability_profiles/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## Struktur Folder

Mengikuti pola Boundary–Control–Entity dari Sequence Diagram:

```
lib/
├── models/          # Entity  (UserAccount, SessionToken, DisabilityProfile)
├── controllers/      # Control (Registration, Auth, Profile, Accessibility)
├── pages/             # Boundary (RegisterPage, LoginPage, ProfilePage, HomePage)
├── services_external/ # Aktor sekunder (DatabaseKampusService — stub)
└── core/              # Shared: theme, firebase service, reusable widgets
```

Nama class di kode ini **sengaja disamakan persis** dengan nama
participant di dokumen Sequence Diagram P6, supaya dosen (atau
anggota kelompok lain) bisa langsung mencocokkan dokumen ke kode
tanpa perlu menerjemahkan ulang.

## Yang masih stub / simulasi di Fase 1

- `DatabaseKampusService.saveDisabilityData()` — belum terhubung ke
  sistem informasi akademik kampus sungguhan, selalu mengembalikan
  `true`. Ganti isi method ini saat integrasi nyata tersedia.
- Enkripsi data disabilitas level-aplikasi (NFR Security) baru
  mengandalkan enkripsi bawaan Firestore (at-rest & in-transit).
  Kalau dosen minta bukti enkripsi eksplisit, ini titik yang perlu
  ditambah di Fase 2.

## Lanjut ke Fase 2

Lihat `accessible_theme.dart` dan `disability_profile.dart` — dua
file ini jadi titik ekstensi utama saat menambah kategori
intelektual & mental/psikososial, serta fitur navigasi (UC-05–08),
AI Learning Assistant (UC-09), dan Buddy System (UC-12–14).
# Difa_plus
