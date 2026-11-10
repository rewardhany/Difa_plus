import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accessibility_controller.dart';
import '../../controllers/map_controller.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../models/campus_map.dart';

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

  /// openCampusMapMenu() -> MapController.showCampusMap()
  Future<void> openCampusMapMenu() async {
    final controller = context.read<MapController>();
    final isNetra = _isNetra;
    _searchController.clear();
    await controller.showCampusMap();
    if (!mounted || !isNetra) return;

    TtsService.instance.speak(
      controller.status == MapLoadStatus.loaded
          ? 'Peta kampus dimuat. ${controller.visibleLocations.length} lokasi tersedia. Pilih lokasi dari daftar.'
          : 'Peta kampus gagal dimuat. Tekan tombol coba lagi.',
    );
  }

  /// selectLocation(locationId) -> MapController.setSelectedLocation()
  void selectLocation(CampusLocation location) {
    context.read<MapController>().setSelectedLocation(location.id);
    if (_isNetra) TtsService.instance.speak(location.audioDescription);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MapController>();
    final isNetra =
        context.watch<AccessibilityController>().profile?.isNetra ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Peta Kampus')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(controller, isNetra),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(MapController controller, bool isNetra) {
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
        return _displayAccessibleCampusMap(controller, isNetra);
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
  Widget _displayAccessibleCampusMap(MapController controller, bool isNetra) {
    final locations = controller.visibleLocations;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccessibleTextField(
          label: 'Cari lokasi',
          controller: _searchController,
          prefixIcon: Icons.search,
          onChanged: controller.setSearchQuery,
        ),
        const SizedBox(height: 12),
        _buildFilters(controller),
        const SizedBox(height: 12),
        if (!isNetra) ...[
          _buildVisualMap(controller),
          const SizedBox(height: 12),
        ],
        _buildSelectedCard(controller),
        const SizedBox(height: 8),
        Text(
          'Daftar Lokasi (${locations.length})',
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

  Widget _buildVisualMap(MapController controller) {
    final scheme = Theme.of(context).colorScheme;
    final selectedId = controller.campusMap?.selectedLocationId;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, box) {
            const markerWidth = 70.0;
            const markerHeight = 62.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(AppColors.border.withAlpha(120)),
                  ),
                ),
                for (final location in controller.visibleLocations)
                  Positioned(
                    left: location.x * (box.maxWidth - markerWidth),
                    top: location.y * (box.maxHeight - markerHeight),
                    child: Semantics(
                      button: true,
                      selected: location.id == selectedId,
                      label: location.name,
                      child: GestureDetector(
                        onTap: () => selectLocation(location),
                        child: SizedBox(
                          width: markerWidth,
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: location.id == selectedId
                                      ? scheme.primary
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.primary,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.place,
                                  size: 22,
                                  color: location.id == selectedId
                                      ? Colors.white
                                      : scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                location.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectedCard(MapController controller) {
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
            // UC-06 Get Campus Route dibangun di update berikutnya.
            const AccessibleButton(
              label: 'Tentukan Rute (segera hadir)',
              icon: Icons.directions,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  const _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
