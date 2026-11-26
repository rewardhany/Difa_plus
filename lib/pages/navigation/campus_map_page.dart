import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accessibility_controller.dart';
import '../../controllers/map_controller.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../models/campus_map.dart';
import '../../models/campus_route.dart';

/// Boundary: CampusMapPage
/// Merealisasikan UC-05 Show Campus Maps.
///
/// Tampilan menyesuaikan profil disabilitas (hasil UC-04):
/// - Netra: mode suara. Tidak ada peta visual, hanya daftar lokasi,
///   dan setiap aksi diumumkan lewat TTS.
/// - Lainnya: peta visual yang bisa disentuh + daftar lokasi.
class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => openCampusMapMenu());
  }

  @override
  void dispose() {
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
    await controller.showCampusMap();
    if (!mounted) return;
    controller.ensureDefaultStart(wheelchairOnly: isFisik);
    if (!isNetra) return;

    TtsService.instance.speak(
      controller.status == MapLoadStatus.loaded
          ? 'Peta Gedung G1 dimuat, 5 lantai tersedia. Pilih lokasi dari daftar.'
          : 'Peta kampus gagal dimuat. Tekan tombol coba lagi.',
    );
  }

  /// UC-06: Hitung rute lalu umumkan ringkasan suara jika mode Netra.
  void _handleCalculateRoute(MapController controller, bool isFisik) {
    controller.ensureDefaultStart(wheelchairOnly: isFisik);
    final ok = controller.calculateRoute(wheelchairOnly: isFisik);
    if (!_isNetra) return;
    if (ok && controller.activeRoute != null) {
      final route = controller.activeRoute!;
      final ringkasan = route.steps.map((s) => s.instruction).join(' ');
      TtsService.instance.speak(
        'Rute ditemukan, jarak sekitar ${route.totalDistanceMeters.round()} meter. $ringkasan',
      );
    } else if (controller.routeError != null) {
      TtsService.instance.speak(controller.routeError!);
    }
  }
  
  /// selectLocation(locationId) -> MapController.setSelectedLocation()
  void selectLocation(CampusLocation location) {
    context.read<MapController>().setSelectedLocation(location.id);
    if (_isNetra) TtsService.instance.speak(location.audioDescription);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MapController>();
    final profile = context.watch<AccessibilityController>().profile;
    final isNetra = profile?.isNetra ?? false;
    final isFisik = profile?.isFisik ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Peta Kampus')),
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
  /// displayAccessibleCampusMap(accessibleMap)
  Widget _displayAccessibleCampusMap(
    MapController controller,
    bool isNetra,
    bool isFisik,
  ) {
    final locations = controller.visibleLocations;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccessibleTextField(
          label: 'Cari ruangan atau lantai',
          controller: _searchController,
          prefixIcon: Icons.search,
          onChanged: controller.setSearchQuery,
        ),
        const SizedBox(height: 12),
        _buildFilters(controller),
        const SizedBox(height: 12),
        _buildFloorSelector(controller),
        const SizedBox(height: 12),
        if (!isNetra) ...[
          _buildVisualMap(controller),
          const SizedBox(height: 12),
        ],
        _buildRouteCard(controller, isFisik),
        _buildSelectedCard(controller, isFisik),
        const SizedBox(height: 8),
        Text(
          controller.searchQuery.isEmpty && controller.activeFilters.isEmpty
              ? 'Daftar Lokasi Lantai ${controller.activeFloor} (${locations.length})'
              : 'Hasil Pencarian (${locations.length})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (locations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tidak ada lokasi yang cocok.'),
          ),
        for (final location in locations) _buildLocationTile(controller, location),
      ],
    );
  }

  /// Pemilih Lantai 1 - 5 (menandai lantai yang dilewati rute aktif).
  Widget _buildFloorSelector(MapController controller) {
    final routeFloors = controller.activeRoute?.floorsInvolved ?? const <int>[];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final floor in controller.floors) ...[
            ChoiceChip(
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
            color: selected ? Theme.of(context).colorScheme.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  /// Denah PNG asli (2000x1125) + garis rute CustomPaint + pin ruangan.
  Widget _buildVisualMap(MapController controller) {
    final scheme = Theme.of(context).colorScheme;
    final selectedId = controller.selectedLocation?.id;
    final startId = controller.startLocationId;
    final route = controller.activeRoute;
    final floor = controller.activeFloor;
    final pins = controller.floorLocations;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: CampusMap.canvasWidth / CampusMap.canvasHeight,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: LayoutBuilder(
                builder: (context, box) {
                  return Stack(
                    children: [
                      // Lapis 1: Gambar denah murni per lantai
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
                      // Lapis 2: Garis jalur rute untuk lantai aktif
                      if (route != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RouteOverlayPainter(
                              route: route,
                              activeFloor: floor,
                              lineColor: scheme.primary,
                            ),
                          ),
                        ),
                      // Lapis 3: Pin lokasi pada lantai aktif
                      for (final location in pins)
                        _buildPin(
                          location: location,
                          box: box,
                          isStart: location.id == startId && route != null,
                          isEnd: location.id == selectedId,
                          primaryColor: scheme.primary,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.surfaceTint,
            child: Text(
              'Lantai $floor • Cubit untuk memperbesar, ketuk titik ruangan untuk memilih',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin({
    required CampusLocation location,
    required BoxConstraints box,
    required bool isStart,
    required bool isEnd,
    required Color primaryColor,
  }) {
    final bool highlight = isStart || isEnd;
    final double dotSize = highlight ? 18 : 12;
    final Color fillColor = isStart
        ? const Color(0xFF16A34A) // Hijau = Titik Awal
        : isEnd
            ? const Color(0xFFDC2626) // Merah = Tujuan / Terpilih
            : location.type == 'lift'
                ? const Color(0xFF7C3AED) // Ungu = Lift
                : location.type == 'stairs'
                    ? const Color(0xFFEA580C) // Oranye = Tangga
                    : primaryColor;

    return Positioned(
      left: location.x * box.maxWidth - (dotSize / 2),
      top: location.y * box.maxHeight - (dotSize / 2),
      child: Semantics(
        button: true,
        selected: isEnd,
        label: '${location.name}, lantai ${location.floor}',
        child: Tooltip(
          message: location.name,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => selectLocation(location),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: highlight ? 2.5 : 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// UC-06: Panel pilih Titik Awal & Tujuan + Daftar Teks Rute.
  Widget _buildRouteCard(MapController controller, bool isFisik) {
    final allLocs = controller.allLocations;
    if (allLocs.isEmpty) return const SizedBox.shrink();

    final route = controller.activeRoute;
    final startId = controller.startLocationId;
    final endId = controller.selectedLocation?.id;

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
                const Icon(Icons.directions, color: AppColors.primary, size: 20),
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
                    label: Text('Ramah Kursi Roda', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationDropdown(
              label: 'Titik Awal',
              value: allLocs.any((l) => l.id == startId) ? startId : null,
              locations: allLocs,
              onChanged: controller.setStartLocation,
            ),
            const SizedBox(height: 10),
            _buildLocationDropdown(
              label: 'Tujuan',
              value: allLocs.any((l) => l.id == endId) ? endId : null,
              locations: allLocs,
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
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => controller.setFloor(
                    route.steps[i].targetFloor ?? route.steps[i].floor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: route.steps[i].isFloorChange
                              ? const Color(0xFF7C3AED)
                              : AppColors.surfaceTint,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: route.steps[i].isFloorChange
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(route.steps[i].instruction),
                        ),
                        Text(
                          'Lt ${route.steps[i].floor}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
                if (location.hasRamp) const Chip(label: Text('Ramp')),
                if (location.hasLift) const Chip(label: Text('Lift')),
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

/// Menggambar garis rute di atas gambar denah PNG khusus untuk lantai aktif.
class _RouteOverlayPainter extends CustomPainter {
  final CampusRoute route;
  final int activeFloor;
  final Color lineColor;

  const _RouteOverlayPainter({
    required this.route,
    required this.activeFloor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

    for (int i = 0; i < route.edges.length; i++) {
      final a = route.path[i];
      final b = route.path[i + 1];
      if (a.floor != activeFloor || b.floor != activeFloor) continue;

      final p1 = Offset(a.x * size.width, a.y * size.height);
      final p2 = Offset(b.x * size.width, b.y * size.height);
      final paint =
          route.edges[i].type == 'stairs' ? stairsPaint : corridorPaint;

      canvas.drawLine(p1, p2, paint);
    }

    // Lingkaran penanda titik pindah lantai (Lift/Tangga) di lantai aktif
    final transferFill = Paint()..color = const Color(0xFF7C3AED);
    final transferBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < route.edges.length; i++) {
      final a = route.path[i];
      final b = route.path[i + 1];
      if (a.floor == b.floor) continue;

      final nodeOnFloor =
          a.floor == activeFloor ? a : (b.floor == activeFloor ? b : null);
      if (nodeOnFloor == null) continue;

      final center =
          Offset(nodeOnFloor.x * size.width, nodeOnFloor.y * size.height);
      canvas.drawCircle(center, 9, transferFill);
      canvas.drawCircle(center, 9, transferBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteOverlayPainter oldDelegate) =>
      oldDelegate.route != route ||
      oldDelegate.activeFloor != activeFloor ||
      oldDelegate.lineColor != lineColor;
}