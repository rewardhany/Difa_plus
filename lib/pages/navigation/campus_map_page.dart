import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accessibility_controller.dart';
import '../../controllers/map_controller.dart';
import '../../core/services/tts_service.dart';
import '../../core/widgets/accessible_button.dart';
import '../../models/campus_map.dart';

/// Boundary: CampusMapPage
/// Merealisasikan UC-05 Show Campus Maps.
///
/// Tampilan menyesuaikan profil disabilitas (hasil UC-04):
/// - Netra: mode suara. Tidak ada peta visual, hanya daftar lokasi besar,
///   dan setiap aksi diumumkan lewat TTS.
/// - Lainnya: peta visual yang bisa disentuh + daftar lokasi.
class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => openCampusMapMenu());
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  bool get _isNetra =>
      context.read<AccessibilityController>().profile?.isNetra ?? false;

  /// openCampusMapMenu() -> MapController.showCampusMap()
  Future<void> openCampusMapMenu() async {
    final controller = context.read<MapController>();
    final isNetra = _isNetra;
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
      body: SafeArea(child: _buildBody(controller, isNetra)),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (locations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tidak ada lokasi yang cocok dengan filter.'),
          ),
        for (final location in locations)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: '${location.name}. ${location.audioDescription}',
            onTap: () => selectLocation(location),
            child: ListTile(
              selected: location.id == controller.campusMap?.selectedLocationId,
              title: Text(location.name),
              subtitle: Text('${location.building} • Lantai ${location.floor}'),
              trailing: Icon(
                location.isWheelchairAccessible
                    ? Icons.accessible
                    : Icons.not_accessible,
              ),
              onTap: () => selectLocation(location),
            ),
          ),
      ],
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
          color: scheme.surfaceContainerHighest,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            const markerWidth = 70.0;
            const markerHeight = 62.0;
            return Stack(
              children: [
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
                              Icon(
                                Icons.place,
                                size: 36,
                                color: location.id == selectedId
                                    ? scheme.error
                                    : scheme.primary,
                              ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location.name, style: Theme.of(context).textTheme.titleLarge),
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
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}
