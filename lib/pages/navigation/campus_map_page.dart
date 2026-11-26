import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accessibility_controller.dart';
import '../../controllers/map_controller.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/virtual_joystick.dart';
import '../../models/campus_map.dart';
import '../../models/campus_route.dart';

/// Boundary: CampusMapPage
/// Merealisasikan UC-05 Show Campus Maps, UC-06 Get Campus Route,
/// serta simulasi posisi real-time mahasiswa disabilitas (joystick & auto-walk).
///
/// Tampilan menyesuaikan profil disabilitas (hasil UC-04):
/// - Netra: mode suara. Tidak ada peta visual, hanya daftar ruangan,
///   kontrol simulasi + panduan suara TTS otomatis.
/// - Lainnya: peta visual bersih (node jalur hanya tampil saat navigasi aktif)
///   + simulasi titik mahasiswa dengan joystick & indikator progres.
class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final AnimationController _pulseController;

  bool _isJoystickActive = false;
  bool _voiceGuidanceEnabled = false;
  int _lastVoiceVersion = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => openCampusMapMenu());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  bool get _isNetra =>
      context.read<AccessibilityController>().profile?.isNetra ?? false;

  bool get _isFisik =>
      context.read<AccessibilityController>().profile?.isFisik ?? false;

  /// openCampusMapMenu() -> MapController.showCampusMap()
  Future<void> openCampusMapMenu() async {
    final controller = context.read<MapController>();
    final isNetra = _isNetra;
    final isFisik = _isFisik;
    _searchController.clear();
    if (isNetra && !_voiceGuidanceEnabled) {
      setState(() => _voiceGuidanceEnabled = true);
    }
    await controller.showCampusMap();
    if (!mounted) return;
    controller.ensureDefaultStart(wheelchairOnly: isFisik);
    _lastVoiceVersion = controller.voicePromptVersion;
    if (!isNetra) return;

    TtsService.instance.speak(
      controller.status == MapLoadStatus.loaded
          ? 'Peta Gedung G1 dimuat, 5 lantai tersedia. Pilih ruangan tujuan dari daftar.'
          : 'Peta kampus gagal dimuat. Tekan tombol coba lagi.',
    );
  }

  /// UC-06: Hitung rute lalu umumkan ringkasan suara jika mode Netra / suara aktif.
  void _handleCalculateRoute(
    MapController controller,
    bool isFisik, {
    bool fromCurrentPosition = false,
  }) {
    controller.ensureDefaultStart(wheelchairOnly: isFisik);
    final ok = fromCurrentPosition
        ? controller.calculateRouteFromCurrentPosition(wheelchairOnly: isFisik)
        : controller.calculateRoute(wheelchairOnly: isFisik);

    if (!(_isNetra || _voiceGuidanceEnabled)) return;
    if (ok && controller.activeRoute != null) {
      final route = controller.activeRoute!;
      final firstStep =
          route.steps.length > 1 ? route.steps[1].instruction : '';
      TtsService.instance.speak(
        'Rute ke ${route.end.shortName} ditemukan, jarak sekitar '
        '${route.totalDistanceMeters.round()} meter. $firstStep',
      );
    } else if (controller.routeError != null) {
      TtsService.instance.speak(controller.routeError!);
    }
  }

  /// selectLocation(locationId) -> MapController.setSelectedLocation()
  void selectLocation(CampusLocation location) {
    context.read<MapController>().setSelectedLocation(location.id);
    if (_isNetra || _voiceGuidanceEnabled) {
      TtsService.instance.speak(location.audioDescription);
    }
  }

  void _checkVoicePrompts(MapController controller, bool isNetra) {
    if (controller.voicePromptVersion == _lastVoiceVersion) return;
    _lastVoiceVersion = controller.voicePromptVersion;
    final prompt = controller.latestVoicePrompt;
    if (prompt == null || prompt.isEmpty) return;
    if (isNetra || _voiceGuidanceEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) TtsService.instance.speak(prompt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MapController>();
    final profile = context.watch<AccessibilityController>().profile;
    final isNetra = profile?.isNetra ?? false;
    final isFisik = profile?.isFisik ?? false;

    _checkVoicePrompts(controller, isNetra);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Kampus'),
        actions: [
          if (controller.status == MapLoadStatus.loaded)
            IconButton(
              tooltip: _voiceGuidanceEnabled || isNetra
                  ? 'Matikan panduan suara'
                  : 'Aktifkan panduan suara',
              icon: Icon(
                _voiceGuidanceEnabled || isNetra
                    ? Icons.volume_up
                    : Icons.volume_off,
              ),
              onPressed: () {
                setState(() {
                  _voiceGuidanceEnabled = !(_voiceGuidanceEnabled || isNetra);
                });
                if (!_voiceGuidanceEnabled) {
                  TtsService.instance.stop();
                } else {
                  TtsService.instance.speak('Panduan suara navigasi diaktifkan.');
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(controller, isNetra, isFisik),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(MapController controller, bool isNetra, bool isFisik) {
    switch (controller.status) {
      case MapLoadStatus.idle:
      case MapLoadStatus.loading:
        return Center(
          child: Semantics(
            label: 'Memuat peta kampus',
            child: const CircularProgressIndicator(),
          ),
        );
      case MapLoadStatus.error:
        return _displayMapRequestError();
      case MapLoadStatus.loaded:
        return _displayAccessibleCampusMap(controller, isNetra, isFisik);
    }
  }

  /// displayMapRequestError() — Exception Flow UC-05.
  Widget _displayMapRequestError() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Data denah kampus gagal diterima. Periksa koneksi lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ),
          const SizedBox(height: 16),
          AccessibleButton(
            label: 'Coba Lagi',
            icon: Icons.refresh,
            onPressed: openCampusMapMenu,
          ),
        ],
      ),
    );
  }

  /// displayAccessibleCampusMap(accessibleMap)
  Widget _displayAccessibleCampusMap(
    MapController controller,
    bool isNetra,
    bool isFisik,
  ) {
    final locations = controller.visibleLocations;

    return ListView(
      physics: _isJoystickActive ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(16),
      children: [
        AccessibleTextField(
          label: 'Cari ruangan atau lantai',
          controller: _searchController,
          prefixIcon: Icons.search,
          onChanged: controller.setSearchQuery,
        ),
        const SizedBox(height: 10),
        _buildFilters(controller),
        const SizedBox(height: 10),
        _buildFloorSelector(controller),
        const SizedBox(height: 12),
        if (!isNetra) ...[
          _buildVisualMap(controller, isFisik),
          const SizedBox(height: 12),
        ],
        _buildSimulationCard(controller, isFisik, isNetra),
        _buildRouteCard(controller, isFisik),
        _buildSelectedCard(controller, isFisik),
        const SizedBox(height: 8),
        Text(
          controller.searchQuery.isEmpty && controller.activeFilters.isEmpty
              ? 'Daftar Ruangan Lantai ${controller.activeFloor} (${locations.length})'
              : 'Hasil Pencarian Ruangan (${locations.length})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (locations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tidak ada ruangan yang cocok.'),
          ),
        for (final location in locations)
          _buildLocationTile(controller, location),
      ],
    );
  }

  /// Pemilih Lantai 1 - 5 (menandai lantai rute aktif dan posisi mahasiswa).
  Widget _buildFloorSelector(MapController controller) {
    final routeFloors = controller.activeRoute?.floorsInvolved ?? const <int>[];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final floor in controller.floors) ...[
            ChoiceChip(
              avatar: controller.hasSimPosition && controller.simFloor == floor
                  ? const Icon(Icons.person_pin_circle, size: 16)
                  : null,
              label: Text(
                routeFloors.contains(floor) ? 'Lt $floor •' : 'Lt $floor',
              ),
              selected: controller.activeFloor == floor,
              onSelected: (_) => controller.setFloor(floor),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationTile(MapController controller, CampusLocation location) {
    final selected = location.id == controller.campusMap?.selectedLocationId;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${location.name}. ${location.audioDescription}',
      onTap: () => selectLocation(location),
      child: Card(
        color: selected ? AppColors.surfaceTint : Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            location.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${location.building} • Lantai ${location.floor}'),
          trailing: Icon(
            location.isWheelchairAccessible
                ? Icons.accessible
                : Icons.not_accessible,
          ),
          onTap: () => selectLocation(location),
        ),
      ),
    );
  }

  /// exploreMap() — filter fasilitas aksesibel.
  Widget _buildFilters(MapController controller) {
    const labels = {
      MapFilter.ramp: 'Ada Ramp',
      MapFilter.lift: 'Ada Lift',
      MapFilter.accessibleToilet: 'Toilet Difabel',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          label: const Text('Semua'),
          selected: controller.activeFilters.isEmpty,
          onSelected: (_) => controller.clearFilters(),
        ),
        for (final filter in MapFilter.values)
          FilterChip(
            label: Text(labels[filter]!),
            selected: controller.activeFilters.contains(filter),
            onSelected: (_) => controller.toggleFilter(filter),
          ),
      ],
    );
  }

  /// Denah PNG asli (2000x1125) + garis rute + node jalur (saat navigasi) + titik mahasiswa.
  Widget _buildVisualMap(MapController controller, bool isFisik) {
    final scheme = Theme.of(context).colorScheme;
    final route = controller.activeRoute;
    final progress = controller.routeProgress;
    final floor = controller.activeFloor;
    final selectedLoc = controller.selectedLocation;
    final startLoc = route?.start ?? controller.startLocation;

    final transfersOnFloor =
        route?.transfersOnFloor(floor) ?? const <FloorTransferPrompt>[];
    final incomingTransfersOnFloor =
        route?.incomingTransfersOnFloor(floor) ?? const <FloorTransferPrompt>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: CampusMap.canvasWidth / CampusMap.canvasHeight,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Lapis 1: Gambar denah murni per lantai (bersih tanpa clutter node)
                          Positioned.fill(
                            child: Image.asset(
                              'assets/maps/lantai_$floor.png',
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Gambar assets/maps/lantai_$floor.png belum ditemukan.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Lapis 2: Garis rute & node jalur (HANYA muncul saat navigasi aktif)
                          if (route != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RouteOverlayPainter(
                                  route: route,
                                  progress: progress,
                                  activeFloor: floor,
                                  simFloor: controller.simFloor,
                                  lineColor: scheme.primary,
                                ),
                              ),
                            ),

                          // Lapis 3: Pin Titik Awal (muncul saat navigasi aktif, atau jika dipilih)
                          if (route != null &&
                              startLoc != null &&
                              startLoc.floor == floor)
                            _buildEndpointMarker(
                              location: startLoc,
                              box: box,
                              color: const Color(0xFF16A34A),
                              badgeText: 'Awal',
                              icon: Icons.trip_origin,
                            ),

                          // Lapis 4: Pin Titik Transfer Lantai (Lift / Tangga) pada jalur rute aktif
                          for (final transfer in transfersOnFloor)
                            _buildTransferMarker(
                              node: transfer.fromNode,
                              edgeType: transfer.edgeType,
                              badgeText:
                                  '${transfer.directionWord} Lt ${transfer.toFloor}',
                              tooltip:
                                  '${transfer.actionLabel} (ketuk untuk lihat Lt ${transfer.toFloor})',
                              box: box,
                              onTap: () => controller.setFloor(transfer.toFloor),
                            ),
                          for (final transfer in incomingTransfersOnFloor)
                            _buildTransferMarker(
                              node: transfer.targetNode,
                              edgeType: transfer.edgeType,
                              badgeText: 'Dari Lt ${transfer.fromFloor}',
                              tooltip:
                                  'Keluar ${transfer.facilityName} dari Lt ${transfer.fromFloor}',
                              box: box,
                              onTap: () =>
                                  controller.setFloor(transfer.fromFloor),
                            ),

                          // Lapis 5: Pin Ruangan Tujuan (muncul saat tujuan dipilih atau navigasi aktif)
                          if (selectedLoc != null && selectedLoc.floor == floor)
                            _buildEndpointMarker(
                              location: selectedLoc,
                              box: box,
                              color: const Color(0xFFDC2626),
                              badgeText: route != null
                                  ? 'Tujuan'
                                  : selectedLoc.shortName,
                              icon: Icons.flag_rounded,
                            ),

                          // Lapis 6: Titik Orang (Simulasi Lokasi Mahasiswa Disabilitas)
                          if (controller.hasSimPosition &&
                              controller.simFloor == floor)
                            _buildStudentMarker(
                              controller: controller,
                              box: box,
                              isFisik: isFisik,
                              primaryColor: scheme.primary,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Tombol cepat kembali ke lantai mahasiswa jika pengguna melihat lantai lain
              if (controller.hasSimPosition && controller.simFloor != floor)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => controller.setFloor(controller.simFloor),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Mahasiswa di Lt ${controller.simFloor}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Legend / keterangan bawah peta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: AppColors.surfaceTint,
            child: route != null
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _legendItem(scheme.primary, 'Mahasiswa'),
                      _legendItem(const Color(0xFF16A34A), 'Sudah dilewati'),
                      _legendItem(const Color(0xFF2563EB), 'Jalur tersisa'),
                      _legendItem(const Color(0xFFDC2626), 'Tujuan'),
                    ],
                  )
                : Text(
                    'Lantai $floor • Pilih ruangan tujuan untuk melihat jalur navigasi',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Pin ringkas dan presisi tepat pada titik pintu ruangan (Awal / Tujuan).
  Widget _buildEndpointMarker({
    required CampusLocation location,
    required BoxConstraints box,
    required Color color,
    required String badgeText,
    required IconData icon,
  }) {
    const double pinSize = 16;
    final cx = location.x * box.maxWidth;
    final cy = location.y * box.maxHeight;
    final placeLabelBelow = location.y < 0.28;

    return Positioned(
      left: cx - (pinSize / 2),
      top: cy - (pinSize / 2),
      width: pinSize,
      height: pinSize,
      child: Tooltip(
        message: location.name,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: pinSize,
              height: pinSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, size: 9, color: Colors.white),
            ),
            Positioned(
              bottom: placeLabelBelow ? null : pinSize + 2,
              top: placeLabelBelow ? pinSize + 2 : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: _mapPillLabel(badgeText, color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Penanda titik transfer antar lantai (Lift / Tangga) khusus pada jalur aktif.
  Widget _buildTransferMarker({
    required CampusLocation node,
    required String edgeType,
    required String badgeText,
    required String tooltip,
    required BoxConstraints box,
    required VoidCallback onTap,
  }) {
    const double pinSize = 18;
    final isLift = edgeType == 'lift';
    final color = isLift ? const Color(0xFF7C3AED) : const Color(0xFFEA580C);
    final cx = node.x * box.maxWidth;
    final cy = node.y * box.maxHeight;

    return Positioned(
      left: cx - (pinSize / 2),
      top: cy - (pinSize / 2),
      width: pinSize,
      height: pinSize,
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: pinSize,
                height: pinSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  isLift ? Icons.elevator : Icons.stairs,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: pinSize + 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: _mapPillLabel(badgeText, color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapPillLabel(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  /// Titik orang (simulasi lokasi mahasiswa disabilitas) dengan radar berdenyut & arah hadap.
  Widget _buildStudentMarker({
    required MapController controller,
    required BoxConstraints box,
    required bool isFisik,
    required Color primaryColor,
  }) {
    const double outerSize = 36;
    const double coreSize = 20;
    final cx = controller.simX * box.maxWidth;
    final cy = controller.simY * box.maxHeight;

    return Positioned(
      left: cx - (outerSize / 2),
      top: cy - (outerSize / 2),
      child: IgnorePointer(
        child: SizedBox(
          width: outerSize,
          height: outerSize,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final t = _pulseController.value;
              final haloSize = coreSize + (outerSize - coreSize) * t;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Radar denyut biru
                  Container(
                    width: haloSize,
                    height: haloSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: (1 - t) * 0.42),
                    ),
                  ),
                  // Panah arah hadap mahasiswa
                  Transform.rotate(
                    angle: controller.simHeadingRad + math.pi / 2,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.arrow_drop_up,
                        size: 16,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Container(
              width: coreSize,
              height: coreSize,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 5,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Icon(
                isFisik ? Icons.accessible : Icons.person,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel Simulasi Lokasi Mahasiswa: Joystick + Progres "Sudah Sampai Mana" + Auto Jalan.
  Widget _buildSimulationCard(
    MapController controller,
    bool isFisik,
    bool isNetra,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final route = controller.activeRoute;
    final progress = controller.routeProgress;
    final landmark = controller.nearestLandmark;
    final pendingTransfer = progress?.pendingTransfer;

    final String positionLabel = landmark != null
        ? 'Lt ${controller.simFloor} • Dekat ${landmark.shortName}'
        : 'Berada di Lantai ${controller.simFloor}';

    final String? activeStepText = (route != null &&
            progress != null &&
            progress.currentStepIndex >= 0 &&
            progress.currentStepIndex < route.steps.length)
        ? route.steps[progress.currentStepIndex].instruction
        : null;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: route != null ? scheme.primary.withValues(alpha: 0.45) : AppColors.border,
          width: route != null ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header simulasi + lokasi saat ini
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    isFisik ? Icons.accessible : Icons.person_pin_circle,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Simulasi Lokasi Mahasiswa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        positionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (progress != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: progress.hasArrived
                          ? const Color(0xFFDCFCE7)
                          : progress.isOffRoute
                              ? const Color(0xFFFEF3C7)
                              : AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      progress.hasArrived
                          ? 'Tiba!'
                          : '${progress.progressPercent}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: progress.hasArrived
                            ? const Color(0xFF15803D)
                            : progress.isOffRoute
                                ? const Color(0xFFB45309)
                                : scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),

            // Indikator progres perjalanan ("sudah sampai mana") saat rute aktif
            if (route != null && progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.progressRatio,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceTint,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.hasArrived
                        ? const Color(0xFF16A34A)
                        : progress.isOffRoute
                            ? const Color(0xFFD97706)
                            : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ditempuh: ~${progress.distanceCoveredMeters.round()} m',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    progress.hasArrived
                        ? 'Sisa: 0 m'
                        : 'Sisa: ~${progress.remainingDistanceMeters.round()} m',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Kotak status aktif (Tiba / Di luar jalur / Pindah lantai / Instruksi saat ini)
              if (progress.hasArrived)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF15803D),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mahasiswa telah tiba di ${route.end.name} (Lantai ${route.end.floor}).',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (progress.isOffRoute)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB45309),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Keluar dari jalur rute. Kembali ke jalur atau hitung ulang dari posisi ini.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => _handleCalculateRoute(
                          controller,
                          isFisik,
                          fromCurrentPosition: true,
                        ),
                        child: const Text('Rute Ulang'),
                      ),
                    ],
                  ),
                )
              else if (activeStepText != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        pendingTransfer != null
                            ? (pendingTransfer.edgeType == 'lift'
                                ? Icons.elevator
                                : Icons.stairs)
                            : Icons.navigation_rounded,
                        size: 18,
                        color: pendingTransfer != null
                            ? const Color(0xFF7C3AED)
                            : scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeStepText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 12),

            // Area Joystick + Tombol Aksi Simulasi
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                VirtualJoystick(
                  size: 112,
                  knobSize: 42,
                  accentColor: scheme.primary,
                  onActiveChanged: (active) {
                    if (_isJoystickActive != active) {
                      setState(() => _isJoystickActive = active);
                    }
                  },
                  onMove: (dx, dy) {
                    // Kecepatan seragam dalam piksel asli pada kanvas 2000x1125
                    const double baseStepX = 0.0042;
                    const double baseStepY = baseStepX *
                        (CampusMap.canvasWidth / CampusMap.canvasHeight);
                    controller.moveStudentBy(dx * baseStepX, dy * baseStepY);
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (pendingTransfer != null) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: pendingTransfer.edgeType == 'lift'
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFEA580C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          icon: Icon(
                            pendingTransfer.edgeType == 'lift'
                                ? Icons.elevator
                                : Icons.stairs,
                            size: 18,
                          ),
                          label: Text(
                            pendingTransfer.actionLabel,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          onPressed: controller.performPendingFloorTransfer,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (route != null) ...[
                        FilledButton.tonalIcon(
                          icon: Icon(
                            controller.isAutoWalking
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(
                            controller.isAutoWalking
                                ? 'Jeda Simulasi'
                                : 'Auto Jalan',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          onPressed: controller.toggleAutoWalk,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text(
                                'Reset',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: controller.resetStudentToStart,
                            ),
                          ),
                          if (controller.selectedLocation != null) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.my_location, size: 16),
                                label: const Text(
                                  'Dari Sini',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _handleCalculateRoute(
                                  controller,
                                  isFisik,
                                  fromCurrentPosition: true,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (route == null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pindah lantai:',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton.outlined(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Turun lantai',
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: controller.simFloor >
                                          controller.floors.first
                                      ? () => controller.moveStudentToFloor(
                                            controller.simFloor - 1,
                                          )
                                      : null,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'Lt ${controller.simFloor}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                IconButton.outlined(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Naik lantai',
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: controller.simFloor <
                                          controller.floors.last
                                      ? () => controller.moveStudentToFloor(
                                            controller.simFloor + 1,
                                          )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// UC-06: Panel pilih Titik Awal & Ruangan Tujuan + Daftar Langkah Rute.
  Widget _buildRouteCard(MapController controller, bool isFisik) {
    final startLocs = controller.startLocations;
    final roomLocs = controller.roomLocations;
    if (roomLocs.isEmpty) return const SizedBox.shrink();

    final route = controller.activeRoute;
    final progress = controller.routeProgress;
    final startId = controller.startLocationId;
    final endId = controller.selectedLocation?.id;

    // Jika titik awal berasal dari "Dari Sini" di titik koridor/lift, tampilkan item dinamis
    final startDropdownItems = List<CampusLocation>.of(startLocs);
    if (startId != null && !startDropdownItems.any((l) => l.id == startId)) {
      final dynamicStart = controller.campusMap?.nodeById(startId);
      if (dynamicStart != null) {
        startDropdownItems.insert(0, dynamicStart);
      }
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.directions,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Navigasi Rute',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (isFisik)
                  const Chip(
                    label: Text(
                      'Ramah Kursi Roda',
                      style: TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationDropdown(
              label: 'Titik Awal',
              value: startDropdownItems.any((l) => l.id == startId)
                  ? startId
                  : null,
              locations: startDropdownItems,
              onChanged: controller.setStartLocation,
            ),
            const SizedBox(height: 10),
            _buildLocationDropdown(
              label: 'Ruangan Tujuan',
              value: roomLocs.any((l) => l.id == endId) ? endId : null,
              locations: roomLocs,
              onChanged: (id) {
                if (id != null) controller.setSelectedLocation(id);
              },
            ),
            if (controller.routeError != null) ...[
              const SizedBox(height: 10),
              Text(
                controller.routeError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    label: 'Cari Rute',
                    icon: Icons.alt_route,
                    onPressed: () => _handleCalculateRoute(controller, isFisik),
                  ),
                ),
                if (route != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Hapus rute',
                    icon: const Icon(Icons.close),
                    onPressed: controller.clearRoute,
                  ),
                ],
              ],
            ),
            if (route != null) ...[
              const Divider(height: 24),
              Text(
                'Estimasi jarak: ~${route.totalDistanceMeters.round()} meter • '
                'Melewati Lantai ${route.floorsInvolved.join(', ')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < route.steps.length; i++)
                _buildRouteStepRow(
                  controller: controller,
                  step: route.steps[i],
                  index: i,
                  progress: progress,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStepRow({
    required MapController controller,
    required RouteStep step,
    required int index,
    required RouteProgress? progress,
  }) {
    final bool isDone = progress != null &&
        (progress.hasArrived || index < progress.currentStepIndex);
    final bool isCurrent = progress != null &&
        !progress.hasArrived &&
        !progress.isOffRoute &&
        index == progress.currentStepIndex;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => controller.setFloor(step.targetFloor ?? step.floor),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.surfaceTint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isCurrent
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: isDone
                  ? const Color(0xFF16A34A)
                  : step.isFloorChange
                      ? const Color(0xFF7C3AED)
                      : isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.surfaceTint,
              child: isDone
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (step.isFloorChange || isCurrent)
                            ? Colors.white
                            : AppColors.primaryDark,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.instruction,
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.normal,
                      color: isDone ? AppColors.textSecondary : null,
                    ),
                  ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Posisi saat ini',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              'Lt ${step.floor}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String? value,
    required List<CampusLocation> locations,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text('Pilih $label'),
          items: [
            for (final loc in locations)
              DropdownMenuItem(
                value: loc.id,
                child: Text(
                  'Lt ${loc.floor} • ${loc.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSelectedCard(MapController controller, bool isFisik) {
    final location = controller.selectedLocation;
    if (location == null) return const SizedBox.shrink();

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('${location.building} • Lantai ${location.floor}'),
            const SizedBox(height: 8),
            Text(location.audioDescription),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (location.hasRamp) const Chip(label: Text('Akses Ramp')),
                if (location.hasLift) const Chip(label: Text('Akses Lift')),
                if (location.hasAccessibleToilet)
                  const Chip(label: Text('Toilet Difabel')),
                if (!location.isWheelchairAccessible)
                  const Chip(label: Text('Tidak ramah kursi roda')),
              ],
            ),
            const SizedBox(height: 12),
            AccessibleButton(
              label: 'Tentukan Rute ke Sini',
              icon: Icons.directions,
              onPressed: () => _handleCalculateRoute(controller, isFisik),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menggambar garis rute + node-node jalur (hanya saat navigasi aktif)
/// dengan pembeda jalur yang sudah dilewati (hijau) vs sisa jalur (biru/oranye).
class _RouteOverlayPainter extends CustomPainter {
  final CampusRoute route;
  final RouteProgress? progress;
  final int activeFloor;
  final int simFloor;
  final Color lineColor;

  const _RouteOverlayPainter({
    required this.route,
    required this.progress,
    required this.activeFloor,
    required this.simFloor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final casingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final passedPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final corridorPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final stairsPaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final int curSeg = progress?.currentSegmentIndex ?? 0;
    final double curT = progress?.segmentT ?? 0.0;
    final bool hasArrived = progress?.hasArrived ?? false;
    final bool isOffRoute = progress?.isOffRoute ?? false;

    // 1. Gambar garis putih pelindung (casing) agar jalur kontras terhadap garis denah hitam
    for (int i = 0; i < route.edges.length; i++) {
      final a = route.path[i];
      final b = route.path[i + 1];
      if (a.floor != activeFloor || b.floor != activeFloor) continue;
      final p1 = Offset(a.x * size.width, a.y * size.height);
      final p2 = Offset(b.x * size.width, b.y * size.height);
      canvas.drawLine(p1, p2, casingPaint);
    }

    // 2. Gambar segmen rute: hijau = sudah dilewati, biru/oranye = sisa jalur
    for (int i = 0; i < route.edges.length; i++) {
      final a = route.path[i];
      final b = route.path[i + 1];
      if (a.floor != activeFloor || b.floor != activeFloor) continue;

      final p1 = Offset(a.x * size.width, a.y * size.height);
      final p2 = Offset(b.x * size.width, b.y * size.height);
      final remainingPaint =
          route.edges[i].type == 'stairs' ? stairsPaint : corridorPaint;

      if (hasArrived || (!isOffRoute && i < curSeg)) {
        canvas.drawLine(p1, p2, passedPaint);
      } else if (!isOffRoute && i == curSeg && activeFloor == simFloor) {
        final mid = Offset.lerp(p1, p2, curT)!;
        if (curT > 0.01) {
          canvas.drawLine(p1, mid, passedPaint);
        }
        if (curT < 0.99) {
          canvas.drawLine(mid, p2, remainingPaint);
        }
      } else {
        canvas.drawLine(p1, p2, remainingPaint);
      }
    }

    // 3. Gambar titik node jalur (waypoint) HANYA untuk node yang dilalui rute di lantai aktif
    final passedDotBorder = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final upcomingDotBorder = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < route.path.length; i++) {
      final node = route.path[i];
      if (node.floor != activeFloor) continue;
      // Lewati start, end, dan transfer karena sudah punya marker pin sendiri
      if (i == 0 || i == route.path.length - 1) continue;
      final isTransferPoint = (i > 0 && route.path[i - 1].floor != node.floor) ||
          (i < route.path.length - 1 && route.path[i + 1].floor != node.floor);
      if (isTransferPoint) continue;

      final center = Offset(node.x * size.width, node.y * size.height);
      final bool isPassed =
          hasArrived || (!isOffRoute && i <= curSeg);

      canvas.drawCircle(center, 3.8, dotFill);
      canvas.drawCircle(
        center,
        3.8,
        isPassed ? passedDotBorder : upcomingDotBorder,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteOverlayPainter oldDelegate) =>
      oldDelegate.route != route ||
      oldDelegate.progress != progress ||
      oldDelegate.activeFloor != activeFloor ||
      oldDelegate.simFloor != simFloor ||
      oldDelegate.lineColor != lineColor;
}
