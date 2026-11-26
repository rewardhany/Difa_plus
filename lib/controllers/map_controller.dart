import 'package:flutter/foundation.dart';
import '../models/campus_map.dart';
import '../services_external/maps_service.dart';
import '../models/campus_route.dart';

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

  int activeFloor = 1;
  String? startLocationId;
  CampusRoute? activeRoute;
  String? routeError;

  /// showCampusMap() — dipanggil CampusMapPage saat peta dibuka.
  Future<void> showCampusMap() async {
    status = MapLoadStatus.loading;
    // Pencarian & filter di-reset tiap peta dibuka supaya sinkron dengan UI.
    searchQuery = '';
    activeFilters.clear();

    activeFloor = 1;
    startLocationId = null;
    activeRoute = null;
    routeError = null;
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
  List<int> get floors => campusMap?.floors ?? const [1];

  /// Semua lokasi yang dapat dipilih sebagai titik awal/tujuan (lintas lantai).
  List<CampusLocation> get allLocations =>
      campusMap?.locations ?? const <CampusLocation>[];

  /// Lokasi pada lantai yang sedang tampil di peta (untuk pin di denah).
  List<CampusLocation> get floorLocations =>
      allLocations.where((l) => l.floor == activeFloor).toList();

  /// Lokasi yang tampil di daftar bawah:
  /// - Jika sedang mencari / memakai filter: cari lintas semua lantai.
  /// - Jika tidak: tampilkan lokasi pada lantai aktif saja agar rapi.
  List<CampusLocation> get visibleLocations {
    final all = allLocations;
    final hasSearchOrFilter =
        searchQuery.isNotEmpty || activeFilters.isNotEmpty;

    return all.where((l) {
      if (!hasSearchOrFilter && l.floor != activeFloor) return false;
      if (searchQuery.isNotEmpty &&
          !'${l.name} ${l.building} lantai ${l.floor}'
              .toLowerCase()
              .contains(searchQuery)) {
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

  CampusLocation? get startLocation =>
      startLocationId == null ? null : campusMap?.nodeById(startLocationId!);

  void setFloor(int floor) {
    if (activeFloor == floor) return;
    activeFloor = floor;
    notifyListeners();
  }

  /// setSelectedLocation(locationId) -> saveSelectedLocation(locationId)
  void setSelectedLocation(String locationId) {
    campusMap?.saveSelectedLocation(locationId);
    final loc = campusMap?.nodeById(locationId);
    if (loc != null) activeFloor = loc.floor;
    notifyListeners();
  }

  /// Mengisi titik awal default:
  /// - Profil Fisik -> Pintu Samping (Ramp)
  /// - Non-Fisik    -> Pintu Utama (Tangga)
  void ensureDefaultStart({required bool wheelchairOnly}) {
    if (startLocationId != null || campusMap == null) return;
    final preferredId = wheelchairOnly ? 'G1-L1-E_SMP' : 'G1-L1-E_UTM';
    if (campusMap!.nodeById(preferredId) != null) {
      startLocationId = preferredId;
    } else if (allLocations.isNotEmpty) {
      startLocationId = allLocations.first.id;
    }
    notifyListeners();
  }

  void setStartLocation(String? locationId) {
    startLocationId = locationId;
    routeError = null;
    notifyListeners();
  }

  /// UC-06 Get Campus Route: hitung jalur terpendek lintas lantai.
  bool calculateRoute({required bool wheelchairOnly}) {
    routeError = null;
    final map = campusMap;
    final startId = startLocationId;
    final endId = selectedLocation?.id;

    if (map == null || startId == null || endId == null) {
      routeError = 'Pilih lokasi awal dan lokasi tujuan terlebih dahulu.';
      activeRoute = null;
      notifyListeners();
      return false;
    }

    final result = RouteFinder.findRoute(
      map: map,
      startId: startId,
      endId: endId,
      wheelchairOnly: wheelchairOnly,
    );

    if (result == null) {
      activeRoute = null;
      routeError = wheelchairOnly
          ? 'Tidak ditemukan rute ramah kursi roda antara dua lokasi ini. '
              'Pastikan titik awal/tujuan bukan tangga (gunakan Pintu Samping/Ramp).'
          : 'Rute antara dua lokasi tersebut tidak ditemukan.';
      notifyListeners();
      return false;
    }

    activeRoute = result;
    // Pindahkan peta ke lantai titik awal agar pengguna langsung melihat awal rute.
    activeFloor = result.start.floor;
    notifyListeners();
    return true;
  }

  void clearRoute() {
    activeRoute = null;
    routeError = null;
    notifyListeners();
  }
}
