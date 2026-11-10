import 'package:flutter/foundation.dart';
import '../models/campus_map.dart';
import '../services_external/maps_service.dart';

enum MapLoadStatus { idle, loading, loaded, error }

/// Filter untuk exploreMap(): menampilkan hanya lokasi dengan fasilitas tertentu.
enum MapFilter { ramp, lift, accessibleToilet }

/// Control: MapController
/// Merealisasikan UC-05 Show Campus Maps.
///
/// Urutan mengikuti Sequence Diagram UC-05:
/// showCampusMap() -> requestMapData() -> buildAccessibleMap()
/// -> (Page) displayAccessibleCampusMap()
/// atau, kalau data gagal diterima -> displayMapRequestError().
/// Lokasi terpilih disimpan lewat setSelectedLocation() ->
/// saveSelectedLocation(), supaya UC-06 Get Campus Route bisa memakainya.
class MapController extends ChangeNotifier {
  MapController({MapsService? mapsService})
      : _mapsService = mapsService ?? MapsService();

  final MapsService _mapsService;

  MapLoadStatus status = MapLoadStatus.idle;
  CampusMap? campusMap;
  final Set<MapFilter> activeFilters = {};
  String searchQuery = '';

  /// showCampusMap() — dipanggil CampusMapPage saat peta dibuka.
  Future<void> showCampusMap() async {
    status = MapLoadStatus.loading;
    // Pencarian & filter di-reset tiap peta dibuka supaya sinkron dengan UI.
    searchQuery = '';
    activeFilters.clear();
    notifyListeners();

    try {
      // requestMapData()
      final mapData = await _mapsService.requestMapData();

      if (mapData == null) {
        // Exception Flow: [Data denah gagal diterima]
        campusMap = null;
        status = MapLoadStatus.error;
        notifyListeners();
        return;
      }

      // buildAccessibleMap(mapData)
      campusMap = CampusMap.buildAccessibleMap(mapData);
      status = MapLoadStatus.loaded;
    } catch (_) {
      campusMap = null;
      status = MapLoadStatus.error;
    }
    notifyListeners();
  }

  /// Lokasi yang tampil setelah pencarian & filter diterapkan.
  List<CampusLocation> get visibleLocations {
    final all = campusMap?.locations ?? const <CampusLocation>[];
    return all.where((l) {
      if (searchQuery.isNotEmpty &&
          !'${l.name} ${l.building}'.toLowerCase().contains(searchQuery)) {
        return false;
      }
      if (activeFilters.contains(MapFilter.ramp) && !l.hasRamp) return false;
      if (activeFilters.contains(MapFilter.lift) && !l.hasLift) return false;
      if (activeFilters.contains(MapFilter.accessibleToilet) &&
          !l.hasAccessibleToilet) {
        return false;
      }
      return true;
    }).toList();
  }

  void setSearchQuery(String query) {
    searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void clearFilters() {
    activeFilters.clear();
    notifyListeners();
  }

  void toggleFilter(MapFilter filter) {
    if (!activeFilters.remove(filter)) activeFilters.add(filter);
    notifyListeners();
  }

  CampusLocation? get selectedLocation => campusMap?.selectedLocation;

  /// setSelectedLocation(locationId) -> saveSelectedLocation(locationId)
  void setSelectedLocation(String locationId) {
    campusMap?.saveSelectedLocation(locationId);
    notifyListeners();
  }
}
