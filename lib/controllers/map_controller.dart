import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../models/campus_map.dart';
import '../models/campus_route.dart';
import '../services_external/maps_service.dart';

enum MapLoadStatus { idle, loading, loaded, error }

/// Filter untuk exploreMap(): menampilkan hanya lokasi dengan fasilitas tertentu.
enum MapFilter { ramp, lift, accessibleToilet }

/// Control: MapController
/// Merealisasikan UC-05 Show Campus Maps, UC-06 Get Campus Route,
/// serta simulasi posisi real-time mahasiswa disabilitas (joystick, auto-walk,
/// dan perpindahan lantai otomatis dengan waktu tunggu 1 detik di Lift/ujung Tangga).
class MapController extends ChangeNotifier {
  MapController({MapsService? mapsService})
      : _mapsService = mapsService ?? MapsService();

  final MapsService _mapsService;

  /// Waktu tunggu di node Lift / ujung Tangga sebelum pindah lantai otomatis.
  static const Duration transferWaitDuration = Duration(seconds: 1);

  /// Radius deteksi (dalam piksel kanvas 2000x1125) agar titik tunggu aktif.
  static const double transferAutoTriggerRadiusPx = 55.0;

  MapLoadStatus status = MapLoadStatus.idle;
  CampusMap? campusMap;
  final Set<MapFilter> activeFilters = {};
  String searchQuery = '';

  int activeFloor = 1;
  String? startLocationId;
  CampusRoute? activeRoute;
  String? routeError;
  VerticalAccessMode verticalAccessMode = VerticalAccessMode.auto;

  // --- State Simulasi Lokasi Mahasiswa Disabilitas ---
  double simX = 0.5;
  double simY = 0.5;
  int simFloor = 1;
  double simHeadingRad = 0.0;
  bool hasSimPosition = false;
  RouteProgress? routeProgress;
  CampusLocation? nearestLandmark;

  // --- State Waktu Tunggu 1 Detik Pindah Lantai Otomatis ---
  Timer? _transferDwellTimer;
  FloorTransferPrompt? activeDwellTransfer;
  double transferDwellProgress = 0.0; // 0.0 .. 1.0
  DateTime? _transferCooldownUntil;

  // --- State Auto-Walk ---
  bool isAutoWalking = false;
  Timer? _autoWalkTimer;
  int _autoSegIndex = 0;
  double _autoSegT = 0.0;
  int _autoTransferPauseTicks = 0;

  // Pelacakan perubahan langkah untuk panduan suara (TTS)
  int? _lastTrackedStepIndex;
  bool _wasOffRoute = false;
  bool _wasArrived = false;
  String? latestVoicePrompt;
  int voicePromptVersion = 0;

  bool get isWaitingFloorTransfer => activeDwellTransfer != null;

  double get transferWaitRemainingSeconds =>
      ((1.0 - transferDwellProgress) *
              (transferWaitDuration.inMilliseconds / 1000.0))
          .clamp(0.0, 1.0);

  /// showCampusMap() — dipanggil CampusMapPage saat peta dibuka.
  Future<void> showCampusMap() async {
    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);
    status = MapLoadStatus.loading;
    searchQuery = '';
    activeFilters.clear();

    activeFloor = 1;
    startLocationId = null;
    activeRoute = null;
    routeError = null;
    routeProgress = null;
    nearestLandmark = null;
    hasSimPosition = false;
    _transferCooldownUntil = null;
    _resetVoiceTracking();
    notifyListeners();

    try {
      final mapData = await _mapsService.requestMapData();

      if (mapData == null) {
        campusMap = null;
        status = MapLoadStatus.error;
        notifyListeners();
        return;
      }

      campusMap = CampusMap.buildAccessibleMap(mapData);
      status = MapLoadStatus.loaded;
    } catch (_) {
      campusMap = null;
      status = MapLoadStatus.error;
    }
    notifyListeners();
  }

  List<int> get floors => campusMap?.floors ?? const [1];

  /// Semua ruangan tujuan (hanya type == 'room', tanpa lift/tangga/junction).
  List<CampusLocation> get roomLocations =>
      campusMap?.locations ?? const <CampusLocation>[];

  /// Alias kompatibilitas: daftar lokasi ruangan.
  List<CampusLocation> get allLocations => roomLocations;

  /// Daftar lokasi awal yang valid: Pintu Masuk (Ramp/Tangga) + semua Ruangan.
  List<CampusLocation> get startLocations =>
      campusMap?.startLocations ?? const <CampusLocation>[];

  /// Ruangan pada lantai aktif.
  List<CampusLocation> get floorLocations =>
      roomLocations.where((l) => l.floor == activeFloor).toList();

  /// Lokasi yang tampil di daftar bawah (hanya ruangan).
  List<CampusLocation> get visibleLocations {
    final all = roomLocations;
    final hasSearchOrFilter =
        searchQuery.isNotEmpty || activeFilters.isNotEmpty;

    return all.where((l) {
      if (!hasSearchOrFilter && l.floor != activeFloor) return false;
      if (searchQuery.isNotEmpty &&
          !'${l.name} ${l.shortName} ${l.building} lantai ${l.floor}'
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

  /// Mengubah preferensi akses antar lantai (Otomatis / Lift / Tangga) bagi non-kursi-roda.
  void setVerticalAccessMode(
    VerticalAccessMode mode, {
    required bool wheelchairOnly,
  }) {
    if (verticalAccessMode == mode) return;
    verticalAccessMode = mode;
    if (activeRoute != null) {
      calculateRoute(wheelchairOnly: wheelchairOnly);
    } else {
      notifyListeners();
    }
  }

  /// setSelectedLocation(locationId) -> saveSelectedLocation(locationId)
  void setSelectedLocation(String locationId) {
    campusMap?.saveSelectedLocation(locationId);
    final loc = campusMap?.nodeById(locationId);
    if (loc != null && activeRoute == null) {
      activeFloor = loc.floor;
    }
    notifyListeners();
  }

  /// Mengisi titik awal default:
  /// - Profil Fisik -> Pintu Samping (Ramp)
  /// - Non-Fisik    -> Pintu Utama (Tangga)
  void ensureDefaultStart({required bool wheelchairOnly}) {
    if (campusMap == null) return;
    if (startLocationId == null) {
      final preferredId = wheelchairOnly ? 'G1-L1-E_SMP' : 'G1-L1-E_UTM';
      if (campusMap!.nodeById(preferredId) != null) {
        startLocationId = preferredId;
      } else if (startLocations.isNotEmpty) {
        startLocationId = startLocations.first.id;
      }
    }
    if (!hasSimPosition) {
      _placeStudentAtNode(startLocation ?? startLocations.firstOrNull);
    }
    notifyListeners();
  }

  void setStartLocation(String? locationId) {
    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);
    startLocationId = locationId;
    routeError = null;
    if (locationId != null) {
      final node = campusMap?.nodeById(locationId);
      if (node != null) {
        _placeStudentAtNode(node);
        activeFloor = node.floor;
      }
    }
    _recomputeProgress(emitVoice: false, checkAutoTransfer: false);
    notifyListeners();
  }

  /// UC-06 Get Campus Route: hitung jalur terpendek lintas lantai.
  bool calculateRoute({
    required bool wheelchairOnly,
    bool keepStudentPosition = false,
  }) {
    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);
    routeError = null;
    final map = campusMap;
    final startId = startLocationId;
    final endId = selectedLocation?.id;

    if (map == null || startId == null || endId == null) {
      routeError = 'Pilih lokasi awal dan ruangan tujuan terlebih dahulu.';
      activeRoute = null;
      routeProgress = null;
      notifyListeners();
      return false;
    }

    final result = RouteFinder.findRoute(
      map: map,
      startId: startId,
      endId: endId,
      wheelchairOnly: wheelchairOnly,
      verticalMode: wheelchairOnly
          ? VerticalAccessMode.liftOnly
          : verticalAccessMode,
    );

    if (result == null) {
      activeRoute = null;
      routeProgress = null;
      routeError = wheelchairOnly
          ? 'Tidak ditemukan rute ramah kursi roda antara dua lokasi ini. '
              'Pastikan titik awal/tujuan bukan tangga (gunakan Pintu Samping/Ramp).'
          : 'Rute antara dua lokasi tersebut tidak ditemukan.';
      notifyListeners();
      return false;
    }

    activeRoute = result;
    _transferCooldownUntil = null;
    _resetVoiceTracking();

    if (!keepStudentPosition || !hasSimPosition) {
      _placeStudentAtNode(result.start);
      if (result.path.length > 1 && result.path[1].floor == result.start.floor) {
        simHeadingRad = math.atan2(
          result.path[1].pixelY - result.start.pixelY,
          result.path[1].pixelX - result.start.pixelX,
        );
      }
    }

    activeFloor = simFloor;
    _recomputeProgress(emitVoice: false, checkAutoTransfer: false);
    notifyListeners();
    return true;
  }

  /// Hitung ulang rute dari posisi mahasiswa simulasi saat ini menuju tujuan terpilih.
  bool calculateRouteFromCurrentPosition({required bool wheelchairOnly}) {
    final map = campusMap;
    if (map == null || !hasSimPosition) {
      return calculateRoute(wheelchairOnly: wheelchairOnly);
    }

    final nearest = map.nearestNode(
      normX: simX,
      normY: simY,
      floor: simFloor,
      wheelchairOnly: wheelchairOnly,
    );
    if (nearest == null) {
      routeError = 'Tidak ditemukan titik koridor terdekat dari posisi saat ini.';
      notifyListeners();
      return false;
    }

    startLocationId = nearest.id;
    return calculateRoute(
      wheelchairOnly: wheelchairOnly,
      keepStudentPosition: true,
    );
  }

  void clearRoute() {
    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);
    activeRoute = null;
    routeError = null;
    routeProgress = null;
    _transferCooldownUntil = null;
    _resetVoiceTracking();
    notifyListeners();
  }

  // ===========================================================================
  // SIMULASI LOKASI MAHASISWA (JOYSTICK, PINDAH LANTAI OTOMATIS 1 DETIK, AUTO-WALK)
  // ===========================================================================

  /// Mengembalikan titik mahasiswa ke lokasi awal.
  void resetStudentToStart() {
    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);
    final node = activeRoute?.start ?? startLocation ?? startLocations.firstOrNull;
    if (node == null) return;
    _placeStudentAtNode(node);
    activeFloor = simFloor;
    _transferCooldownUntil = null;
    _resetVoiceTracking();
    _recomputeProgress(emitVoice: false, checkAutoTransfer: false);
    notifyListeners();
  }

  /// Menggerakkan titik mahasiswa dengan vektor delta ternormalisasi (dari joystick).
  void moveStudentBy(double dxNorm, double dyNorm) {
    if (campusMap == null) return;
    if (!hasSimPosition) {
      _placeStudentAtNode(startLocation ?? startLocations.firstOrNull);
    }
    if (isAutoWalking) {
      stopAutoWalk(notify: false);
    }

    // Batas area dalam bangunan pada kanvas 2000 x 1125
    simX = (simX + dxNorm).clamp(0.14, 0.86);
    simY = (simY + dyNorm).clamp(0.08, 0.94);

    if (dxNorm.abs() > 1e-5 || dyNorm.abs() > 1e-5) {
      simHeadingRad = math.atan2(
        dyNorm * CampusMap.canvasHeight,
        dxNorm * CampusMap.canvasWidth,
      );
    }

    if (activeFloor != simFloor) {
      activeFloor = simFloor;
    }

    _updateNearestLandmark();
    _recomputeProgress(emitVoice: true, checkAutoTransfer: true);
    notifyListeners();
  }

  /// Menjalankan perpindahan lantai (dipanggil otomatis setelah tunggu 1 detik atau manual).
  void performPendingFloorTransfer() {
    final transfer = activeDwellTransfer ?? routeProgress?.pendingTransfer;
    if (transfer == null) return;

    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);
    _transferCooldownUntil =
        DateTime.now().add(const Duration(milliseconds: 1200));

    _placeStudentAtNode(transfer.targetNode);
    activeFloor = transfer.targetNode.floor;
    _recomputeProgress(emitVoice: false, checkAutoTransfer: false);

    final nextInstr = _currentStepInstruction();
    _emitVoicePrompt(
      'Tiba di Lantai ${transfer.toFloor} melalui ${transfer.facilityName}. '
      '${nextInstr ?? ''}'.trim(),
    );
    notifyListeners();
  }

  /// Memindahkan mahasiswa simulasi ke lantai lain secara manual (saat eksplorasi tanpa rute).
  void moveStudentToFloor(int targetFloor) {
    if (campusMap == null || !floors.contains(targetFloor)) return;
    stopAutoWalk(notify: false);
    _cancelTransferDwell(notify: false);

    final liftsOnTarget = campusMap!.allNodes
        .where((n) => n.floor == targetFloor && n.type == 'lift')
        .toList();

    CampusLocation? landing;
    if (liftsOnTarget.isNotEmpty) {
      liftsOnTarget.sort((a, b) =>
          CampusMap.distancePx(simX, simY, a.x, a.y)
              .compareTo(CampusMap.distancePx(simX, simY, b.x, b.y)));
      landing = liftsOnTarget.first;
    } else {
      landing = campusMap!.nearestNode(
        normX: simX,
        normY: simY,
        floor: targetFloor,
      );
    }

    if (landing != null) {
      _placeStudentAtNode(landing);
    } else {
      simFloor = targetFloor;
      hasSimPosition = true;
    }
    activeFloor = simFloor;
    _recomputeProgress(emitVoice: true, checkAutoTransfer: false);
    notifyListeners();
  }

  /// Memulai atau menjeda simulasi jalan otomatis mengikuti jalur rute aktif.
  void toggleAutoWalk() {
    if (isAutoWalking) {
      stopAutoWalk();
      return;
    }
    final route = activeRoute;
    if (route == null || route.edges.isEmpty) return;

    _cancelTransferDwell(notify: false);

    final prog = routeProgress;
    if (prog == null || prog.hasArrived || prog.isOffRoute) {
      _placeStudentAtNode(route.start);
      activeFloor = simFloor;
      _autoSegIndex = 0;
      _autoSegT = 0.0;
      _resetVoiceTracking();
    } else {
      _autoSegIndex = prog.currentSegmentIndex.clamp(0, route.edges.length - 1);
      _autoSegT = prog.segmentT.clamp(0.0, 1.0);
    }

    _autoTransferPauseTicks = 0;
    isAutoWalking = true;
    _recomputeProgress(emitVoice: true, checkAutoTransfer: false);
    notifyListeners();

    _autoWalkTimer?.cancel();
    _autoWalkTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _tickAutoWalk(),
    );
  }

  void stopAutoWalk({bool notify = true}) {
    _autoWalkTimer?.cancel();
    _autoWalkTimer = null;
    if (isAutoWalking) {
      isAutoWalking = false;
      activeDwellTransfer = null;
      transferDwellProgress = 0.0;
      if (notify) notifyListeners();
    }
  }

  void _tickAutoWalk() {
    final route = activeRoute;
    if (route == null || !isAutoWalking) {
      stopAutoWalk();
      return;
    }

    if (_autoSegIndex >= route.edges.length) {
      _placeStudentAtNode(route.end);
      activeFloor = simFloor;
      stopAutoWalk(notify: false);
      _recomputeProgress(emitVoice: true, checkAutoTransfer: false);
      notifyListeners();
      return;
    }

    final a = route.path[_autoSegIndex];
    final b = route.path[_autoSegIndex + 1];

    // Perpindahan lantai (Lift / ujung Tangga): tunggu tepat 1 detik (30 tick x 33ms)
    if (a.floor != b.floor) {
      const int waitTicks = 30;
      final edgeType = route.edges[_autoSegIndex].type;
      int j = _autoSegIndex;
      while (j < route.edges.length &&
          route.path[j].floor != route.path[j + 1].floor &&
          route.edges[j].type == edgeType) {
        j++;
      }
      final target = route.path[j];

      if (_autoTransferPauseTicks == 0) {
        activeDwellTransfer = FloorTransferPrompt(
          fromFloor: a.floor,
          toFloor: target.floor,
          facilityName: a.name,
          edgeType: edgeType,
          fromNode: a,
          targetNode: target,
          fromPathIndex: _autoSegIndex,
          targetPathIndex: j,
        );
        _emitVoicePrompt(
          'Tunggu 1 detik di ${a.name} untuk '
          '${target.floor > a.floor ? 'naik' : 'turun'} ke Lantai ${target.floor}.',
        );
      }

      if (_autoTransferPauseTicks < waitTicks) {
        _autoTransferPauseTicks++;
        transferDwellProgress =
            (_autoTransferPauseTicks / waitTicks).clamp(0.0, 1.0);
        notifyListeners();
        return;
      }

      _autoTransferPauseTicks = 0;
      activeDwellTransfer = null;
      transferDwellProgress = 0.0;

      _placeStudentAtNode(target);
      activeFloor = target.floor;
      _autoSegIndex = j;
      _autoSegT = 0.0;
      _recomputeProgress(emitVoice: true, checkAutoTransfer: false);
      notifyListeners();
      return;
    }

    // Pergerakan halus di lantai yang sama (~210 px per detik pada kanvas 2000 px)
    const double speedPxPerTick = 7.0;
    final dx = b.pixelX - a.pixelX;
    final dy = b.pixelY - a.pixelY;
    final segLen = math.sqrt(dx * dx + dy * dy);

    if (segLen <= 1e-3) {
      _autoSegIndex++;
      _autoSegT = 0.0;
    } else {
      _autoSegT += speedPxPerTick / segLen;
      simHeadingRad = math.atan2(dy, dx);

      if (_autoSegT >= 1.0) {
        _autoSegIndex++;
        _autoSegT = 0.0;
        simX = b.x;
        simY = b.y;
        simFloor = b.floor;
      } else {
        simX = (a.pixelX + dx * _autoSegT) / CampusMap.canvasWidth;
        simY = (a.pixelY + dy * _autoSegT) / CampusMap.canvasHeight;
        simFloor = a.floor;
      }
    }

    activeFloor = simFloor;
    _updateNearestLandmark();
    _recomputeProgress(emitVoice: true, checkAutoTransfer: false);

    if (_autoSegIndex >= route.edges.length ||
        (routeProgress?.hasArrived ?? false)) {
      _placeStudentAtNode(route.end);
      activeFloor = simFloor;
      stopAutoWalk(notify: false);
      _recomputeProgress(emitVoice: true, checkAutoTransfer: false);
    }

    notifyListeners();
  }

  /// Mengevaluasi apakah mahasiswa sedang berada di titik tunggu 1 detik (Lift / ujung Tangga).
  void _evaluateAutoTransferDwell() {
    if (isAutoWalking) return;

    final now = DateTime.now();
    if (_transferCooldownUntil != null && now.isBefore(_transferCooldownUntil!)) {
      _cancelTransferDwell(notify: false);
      return;
    }

    final transfer = routeProgress?.pendingTransfer;
    final distPx = routeProgress?.pendingTransferDistancePx ?? double.infinity;

    if (transfer != null && distPx <= transferAutoTriggerRadiusPx) {
      // Sudah sedang menghitung mundur untuk transfer yang sama
      if (activeDwellTransfer?.fromNode.id == transfer.fromNode.id &&
          _transferDwellTimer != null) {
        return;
      }

      _cancelTransferDwell(notify: false);
      activeDwellTransfer = transfer;
      transferDwellProgress = 0.0;
      _emitVoicePrompt(
        'Tunggu 1 detik di ${transfer.facilityName} untuk '
        '${transfer.directionWord.toLowerCase()} ke Lantai ${transfer.toFloor}.',
      );

      const int stepMs = 50;
      final double progressPerTick =
          stepMs / transferWaitDuration.inMilliseconds;

      _transferDwellTimer = Timer.periodic(
        const Duration(milliseconds: stepMs),
        (_) {
          if (activeDwellTransfer == null || activeRoute == null) {
            _cancelTransferDwell(notify: true);
            return;
          }
          transferDwellProgress =
              (transferDwellProgress + progressPerTick).clamp(0.0, 1.0);
          if (transferDwellProgress >= 1.0) {
            performPendingFloorTransfer();
          } else {
            notifyListeners();
          }
        },
      );
    } else if (activeDwellTransfer != null) {
      // Mahasiswa menjauh dari titik Lift/ujung Tangga sebelum 1 detik selesai
      _cancelTransferDwell(notify: false);
    }
  }

  void _cancelTransferDwell({bool notify = true}) {
    _transferDwellTimer?.cancel();
    _transferDwellTimer = null;
    final hadDwell =
        activeDwellTransfer != null || transferDwellProgress != 0.0;
    activeDwellTransfer = null;
    transferDwellProgress = 0.0;
    if (notify && hadDwell) notifyListeners();
  }

  void _placeStudentAtNode(CampusLocation? node) {
    if (node == null) return;
    simX = node.x;
    simY = node.y;
    simFloor = node.floor;
    hasSimPosition = true;
    _updateNearestLandmark();
  }

  void _updateNearestLandmark() {
    if (campusMap == null || !hasSimPosition) {
      nearestLandmark = null;
      return;
    }
    nearestLandmark = campusMap!.nearestNode(
      normX: simX,
      normY: simY,
      floor: simFloor,
      namedOnly: true,
    );
  }

  void _recomputeProgress({
    required bool emitVoice,
    required bool checkAutoTransfer,
  }) {
    final route = activeRoute;
    if (route == null || !hasSimPosition) {
      routeProgress = null;
      _cancelTransferDwell(notify: false);
      return;
    }

    final progress = route.evaluateProgress(
      normX: simX,
      normY: simY,
      floor: simFloor,
    );
    routeProgress = progress;

    if (checkAutoTransfer) {
      _evaluateAutoTransferDwell();
    }

    if (!emitVoice) {
      _lastTrackedStepIndex = progress.currentStepIndex;
      _wasOffRoute = progress.isOffRoute;
      _wasArrived = progress.hasArrived;
      return;
    }

    if (progress.hasArrived && !_wasArrived) {
      _wasArrived = true;
      _wasOffRoute = false;
      _lastTrackedStepIndex = progress.currentStepIndex;
      _emitVoicePrompt(
        'Anda telah tiba di tujuan: ${route.end.name}, Lantai ${route.end.floor}.',
      );
      return;
    }

    if (progress.isOffRoute && !_wasOffRoute) {
      _wasOffRoute = true;
      _emitVoicePrompt(
        'Anda keluar dari jalur rute. Kembali ke jalur atau tekan hitung ulang rute.',
      );
      return;
    } else if (!progress.isOffRoute) {
      _wasOffRoute = false;
    }

    // Jika sedang menunggu transfer 1 detik, jangan timpa pengumuman tunggu
    if (isWaitingFloorTransfer) return;

    if (progress.currentStepIndex != _lastTrackedStepIndex &&
        !progress.isOffRoute) {
      _lastTrackedStepIndex = progress.currentStepIndex;
      final instr = _currentStepInstruction();
      if (instr != null && instr.isNotEmpty) {
        _emitVoicePrompt(instr);
      }
    }
  }

  String? _currentStepInstruction() {
    final route = activeRoute;
    final prog = routeProgress;
    if (route == null || prog == null) return null;
    if (prog.currentStepIndex < 0 ||
        prog.currentStepIndex >= route.steps.length) {
      return null;
    }
    return route.steps[prog.currentStepIndex].instruction;
  }

  void _emitVoicePrompt(String text) {
    latestVoicePrompt = text;
    voicePromptVersion++;
  }

  void _resetVoiceTracking() {
    _lastTrackedStepIndex = null;
    _wasOffRoute = false;
    _wasArrived = false;
  }

  @override
  void dispose() {
    _autoWalkTimer?.cancel();
    _transferDwellTimer?.cancel();
    super.dispose();
  }
}
