import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/map_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/scene_illustration.dart';
import '../../models/campus_map.dart';
import '../../models/disability_profile.dart';
import '../../models/user_account.dart';

/// Boundary: HomePage
/// Merealisasikan "viewAdaptedHomeScreen()" pada UC-04, sekaligus
/// pintu masuk ke fitur yang sudah selesai dibangun.
///
/// Tab bawah: Beranda, Peta (membuka halaman peta), AI Konversi
/// (placeholder, UC-09), Profil.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _bannerDismissed = false; // banner "Lengkapi profil" ditutup (hanya sesi ini)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final map = context.read<MapController>();
      if (map.status == MapLoadStatus.idle) map.showCampusMap();
    });
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature segera hadir.')),
    );
  }

  void _openMap() => Navigator.of(context).pushNamed('/campus-map');

  void _onDestination(int index) {
    if (index == 1) {
      _openMap();
      return;
    }
    setState(() => _tab = index);
  }

  Future<void> _logout() async {
    final auth = context.read<AuthController>();
    final accessibility = context.read<AccessibilityController>();
    await auth.logout();
    accessibility.reset();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final accessibility = context.watch<AccessibilityController>();
    final name = auth.currentAccount?.fullName ?? 'Pengguna';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const DifaLogo(size: 30),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifikasi',
            onPressed: () => _comingSoon('Notifikasi'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              label: 'Profil saya',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _tab = 3),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildTab(auth, accessibility, name, initial),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Peta',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI Konversi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    AuthController auth,
    AccessibilityController accessibility,
    String name,
    String initial,
  ) {
    switch (_tab) {
      case 2:
        return _buildAiTab();
      case 3:
        return _buildProfileTab(auth, accessibility, name, initial);
      default:
        return _buildHomeTab(accessibility, name);
    }
  }

  // ---------------------------------------------------------------- Beranda

  Widget _buildHomeTab(AccessibilityController accessibility, String name) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = name.trim().split(' ').first;
    final map = context.watch<MapController>();
    final auth = context.watch<AuthController>();
    final missing = _missingItems(auth, accessibility);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Halo, $firstName 👋',
          style:
              textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          'Semangat hari ini!',
          style:
              textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (missing.isNotEmpty && !_bannerDismissed) ...[
          _CompleteProfileBanner(
            missing: missing,
            onComplete: () =>
                Navigator.of(context).pushNamed('/complete-profile'),
            onDismiss: () => setState(() => _bannerDismissed = true),
          ),
          const SizedBox(height: 16),
        ],
        _SearchBar(onTap: _openMap),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuickAction(
                icon: Icons.map_outlined,
                label: 'Peta Kampus',
                color: AppColors.primary,
                onTap: _openMap,
              ),
              _QuickAction(
                icon: Icons.alt_route,
                label: 'Rute',
                color: const Color(0xFF0D9488),
                onTap: () => _comingSoon('Rute & Navigasi'),
              ),
              _QuickAction(
                icon: Icons.auto_awesome,
                label: 'Materi AI',
                color: const Color(0xFF7C3AED),
                onTap: () => _comingSoon('Materi Aksesibel (AI)'),
              ),
              _QuickAction(
                icon: Icons.volunteer_activism,
                label: 'Pendamping',
                color: const Color(0xFFEA580C),
                onTap: () => _comingSoon('Pendamping'),
              ),
              _QuickAction(
                icon: Icons.feedback_outlined,
                label: 'Lapor',
                color: const Color(0xFFDB2777),
                onTap: () => _comingSoon('Lapor Hambatan'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _IllustratedBanner(),
        const SizedBox(height: 12),
        _ModeInfo(
          text: _modeDescription(
            accessibility.profile,
            auth.currentAccount?.role,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Fasilitas Aksesibel',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(onPressed: _openMap, child: const Text('Lihat semua')),
          ],
        ),
        const SizedBox(height: 8),
        _buildFacilities(map),
      ],
    );
  }

  Widget _buildFacilities(MapController map) {
    if (map.status == MapLoadStatus.idle ||
        map.status == MapLoadStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (map.status == MapLoadStatus.error) {
      return const Text('Data fasilitas belum bisa dimuat.');
    }
    final items = (map.campusMap?.locations ?? const <CampusLocation>[])
        .where((l) => l.isWheelchairAccessible)
        .take(6)
        .toList();

    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            _FacilityCard(location: items[i], onTap: _openMap),
      ),
    );
  }

  /// Data profil yang masih kosong (untuk banner "Lengkapi profil").
  List<String> _missingItems(
    AuthController auth,
    AccessibilityController accessibility,
  ) {
    final account = auth.currentAccount;
    if (account == null) return const [];
    final missing = <String>[];
    if (!account.hasPhone) missing.add('No. telepon');
    if (account.role == UserRole.mahasiswa &&
        (accessibility.profile?.isEmpty ?? true)) {
      missing.add('Jenis disabilitas');
    }
    if (!auth.hasPassword) missing.add('Password');
    return missing;
  }

  String _modeDescription(DisabilityProfile? profile, [UserRole? role]) {
    if (role == UserRole.pendamping) {
      return 'Tampilan standar untuk akun pendamping.';
    }
    if (profile == null || profile.isEmpty) {
      return 'Tampilan standar — belum ada kategori disabilitas yang diatur.';
    }
    if (profile.isNetra) {
      return 'Mode tampilan: kontras tinggi & teks besar, dioptimalkan untuk screen reader.';
    }
    if (profile.isFisik) {
      return 'Mode tampilan: target sentuh diperbesar untuk kemudahan navigasi.';
    }
    return 'Mode tampilan: standar, notifikasi disesuaikan untuk kebutuhan dengar/bicara.';
  }

  // ------------------------------------------------------------ AI Konversi

  Widget _buildAiTab() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.auto_awesome, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'AI Konversi segera hadir',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ubah materi kuliah menjadi audio atau teks sesuai kebutuhanmu (UC-09).',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Profil

  Widget _buildProfileTab(
    AuthController auth,
    AccessibilityController accessibility,
    String name,
    String initial,
  ) {
    final account = auth.currentAccount;
    final textTheme = Theme.of(context).textTheme;
    final categories =
        accessibility.profile?.categories ?? const <DisabilityCategory>[];
    final isMahasiswa = account == null || account.role == UserRole.mahasiswa;
    final missing = _missingItems(auth, accessibility);
    final categoryText = categories.isEmpty
        ? 'Belum diisi'
        : categories.map((c) => c.label).join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            name,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (account != null) ...[
          Center(
            child: Text(
              '${account.role.label} • ${account.email}',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              avatar: Icon(
                auth.isGoogleAccount
                    ? Icons.verified_user_outlined
                    : Icons.mail_outline,
                size: 16,
              ),
              label: Text(
                auth.isGoogleAccount ? 'Masuk dengan Google' : 'Masuk dengan email',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            rows: [
              _InfoRow('Nama', account.fullName),
              _InfoRow('Email', account.email),
              _InfoRow(
                'No. telepon',
                account.hasPhone ? account.phone! : 'Belum diisi',
                warn: !account.hasPhone,
              ),
              _InfoRow('Peran', account.role.label),
              if (isMahasiswa)
                _InfoRow('Jenis disabilitas', categoryText,
                    warn: categories.isEmpty),
              _InfoRow(
                'Password',
                auth.hasPassword ? 'Sudah dibuat' : 'Belum dibuat',
                warn: !auth.hasPassword,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.edit_outlined,
              title: missing.isNotEmpty ? 'Lengkapi Profil' : 'Edit Profil',
              subtitle: auth.hasPassword
                  ? 'Nama, no. telepon'
                  : 'Nama, no. telepon, password',
              onTap: () => Navigator.of(context).pushNamed('/complete-profile'),
            ),
            if (isMahasiswa)
              _MenuTile(
                icon: Icons.accessible_forward,
                title: 'Profil Disabilitas',
                subtitle: categoryText,
                onTap: () => Navigator.of(context).pushNamed('/profile'),
              ),
            if (account != null && !auth.hasPassword)
              _MenuTile(
                icon: Icons.lock_outline,
                title: 'Atur Password',
                subtitle: 'Agar bisa login dengan email',
                onTap: () =>
                    Navigator.of(context).pushNamed('/complete-profile'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ModeInfo(text: _modeDescription(accessibility.profile, account?.role)),
        const SizedBox(height: 20),
        AccessibleButton(
          label: 'Keluar',
          icon: Icons.logout,
          outlined: true,
          onPressed: _logout,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Widget kecil

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Cari fasilitas atau lokasi di peta',
      onTap: onTap,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cari fasilitas atau lokasi...',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withAlpha(31),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustratedBanner extends StatelessWidget {
  const _IllustratedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCEBFF), Color(0xFFC9E0FF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Setiap orang berhak mengakses layanan kampus dengan mudah.',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: SceneIllustration(variant: SceneVariant.banner),
          ),
        ],
      ),
    );
  }
}

class _ModeInfo extends StatelessWidget {
  final String text;

  const _ModeInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.tune, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final CampusLocation location;
  final VoidCallback onTap;

  const _FacilityCard({required this.location, required this.onTap});

  IconData get _icon {
    final id = location.id;
    if (id.contains('toilet')) return Icons.wc;
    if (id.contains('perpustakaan')) return Icons.local_library;
    if (id.contains('kantin')) return Icons.restaurant;
    if (id.contains('uld')) return Icons.support_agent;
    if (id.contains('gerbang')) return Icons.door_front_door;
    return Icons.apartment;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${location.name}, lantai ${location.floor}',
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    width: double.infinity,
                    color: AppColors.surfaceTint,
                    child: Icon(_icon, size: 40, color: AppColors.primary),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lantai ${location.floor}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------- Banner & kartu profil

class _CompleteProfileBanner extends StatelessWidget {
  final List<String> missing;
  final VoidCallback onComplete;
  final VoidCallback onDismiss;

  const _CompleteProfileBanner({
    required this.missing,
    required this.onComplete,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB45309);
    return Semantics(
      container: true,
      label: 'Lengkapi profil kamu. Belum diisi: ${missing.join(', ')}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.info_outline, color: amber),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Lengkapi profil kamu',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Tutup',
                  onPressed: onDismiss,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 34, right: 12),
              child: Text('Belum diisi: ${missing.join(', ')}.'),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: ElevatedButton(
                onPressed: onComplete,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('Lengkapi sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool warn;

  const _InfoRow(this.label, this.value, {this.warn = false});
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      r.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: r.warn ? const Color(0xFFB45309) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
