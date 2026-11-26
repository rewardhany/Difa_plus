/// Entity: CampusMap (+ CampusLocation)
/// Dipakai pada UC-05 Show Campus Maps, lalu UC-06, UC-07, UC-08.
///
/// Sesuai Sequence Diagram UC-05: CampusMap bertugas menyusun denah
/// aksesibel (buildAccessibleMap) dan menyimpan lokasi terpilih
/// (saveSelectedLocation) supaya bisa dipakai UC-06 lewat <<include>>.
library;

import 'dart:math' as math;

class CampusLocation {
  final String id;
  final String name;
  final String shortName;
  final String building;
  final int floor;

  /// Tipe node pada graf: room, junction, entrance, lift, stairs.
  final String type;

  /// Posisi piksel asli pada kanvas denah 2000 x 1125 px.
  final double pixelX;
  final double pixelY;

  /// Posisi ternormalisasi (0.0 - 1.0) untuk render responsif di layar HP.
  final double x;
  final double y;

  /// Deskripsi yang dibacakan TTS untuk mahasiswa netra.
  final String audioDescription;

  final bool hasRamp;
  final bool hasLift;
  final bool hasAccessibleToilet;

  const CampusLocation({
    required this.id,
    required this.name,
    String? shortName,
    required this.building,
    required this.floor,
    this.type = 'room',
    required this.pixelX,
    required this.pixelY,
    required this.x,
    required this.y,
    required this.audioDescription,
    this.hasRamp = false,
    this.hasLift = false,
    this.hasAccessibleToilet = false,
  }) : shortName = shortName ?? name;

  bool get isRoom => type == 'room';
  bool get isEntrance => type == 'entrance';
  bool get isTransfer => type == 'lift' || type == 'stairs';
  bool get isJunction => type == 'junction';

  /// Ramah kursi roda jika bukan tangga dan bukan Pintu Utama (Tangga).
  bool get isWheelchairAccessible => type != 'stairs' && id != 'G1-L1-E_UTM';

  factory CampusLocation.fromMap(
    Map<String, dynamic> map, {
    String defaultBuilding = 'Gedung G1',
    double canvasWidth = CampusMap.canvasWidth,
    double canvasHeight = CampusMap.canvasHeight,
    bool floorHasLift = false,
    bool floorHasRamp = false,
  }) {
    final id = map['id'] as String;
    final name = map['name'] as String? ?? 'Lokasi';
    final shortName = (map['short_name'] as String?)?.trim();
    final building = map['building'] as String? ?? defaultBuilding;
    final floor = (map['floor'] as num?)?.toInt() ?? 1;
    final type = map['type'] as String? ?? 'room';

    final rawX = (map['x'] as num?)?.toDouble() ?? (canvasWidth / 2);
    final rawY = (map['y'] as num?)?.toDouble() ?? (canvasHeight / 2);
    // Jika koordinat > 1.0 berarti dalam piksel (format difa_G1_graph.json).
    final isPixel = rawX > 1.0 || rawY > 1.0;
    final pixelX = isPixel ? rawX : rawX * canvasWidth;
    final pixelY = isPixel ? rawY : rawY * canvasHeight;
    final normX = isPixel ? (rawX / canvasWidth) : rawX;
    final normY = isPixel ? (rawY / canvasHeight) : rawY;

    final lowerName = name.toLowerCase();
    final wheelchairOk = type != 'stairs' && id != 'G1-L1-E_UTM';

    final hasRamp = (map['hasRamp'] as bool?) ??
        (lowerName.contains('ramp') ||
            id == 'G1-L1-E_SMP' ||
            (type == 'room' && floorHasRamp && wheelchairOk));
    final hasLift = (map['hasLift'] as bool?) ??
        (type == 'lift' || (type == 'room' && floorHasLift && wheelchairOk));
    final hasAccessibleToilet = (map['hasAccessibleToilet'] as bool?) ??
        lowerName.contains('toilet');

    final defaultDesc = _buildAudioDescription(
      name: name,
      building: building,
      floor: floor,
      type: type,
      wheelchairAccessible: wheelchairOk,
    );

    return CampusLocation(
      id: id,
      name: name,
      shortName: (shortName != null && shortName.isNotEmpty) ? shortName : name,
      building: building,
      floor: floor,
      type: type,
      pixelX: pixelX,
      pixelY: pixelY,
      x: normX,
      y: normY,
      audioDescription: map['audioDescription'] as String? ?? defaultDesc,
      hasRamp: hasRamp,
      hasLift: hasLift,
      hasAccessibleToilet: hasAccessibleToilet,
    );
  }

  static String _buildAudioDescription({
    required String name,
    required String building,
    required int floor,
    required String type,
    required bool wheelchairAccessible,
  }) {
    if (type == 'lift') {
      return '$name, $building lantai $floor. Penghubung antar lantai ramah kursi roda.';
    }
    if (type == 'stairs') {
      return '$name, $building lantai $floor. Akses tangga, tidak ramah kursi roda.';
    }
    final akses = wheelchairAccessible
        ? 'Dapat diakses kursi roda.'
        : 'Menggunakan tangga, tidak ramah kursi roda.';
    return '$name, $building lantai $floor. $akses';
  }
}

/// Edge penghubung antar node (koridor di 1 lantai atau lift/tangga antar lantai).
class CampusEdge {
  final String from;
  final String to;
  final double weightPx;
  final String type; // corridor, lift, stairs
  final bool wheelchair;

  const CampusEdge({
    required this.from,
    required this.to,
    required this.weightPx,
    required this.type,
    required this.wheelchair,
  });

  factory CampusEdge.fromMap(Map<String, dynamic> map) {
    final weight = (map['length_px'] as num?)?.toDouble() ??
        (map['cost_px'] as num?)?.toDouble() ??
        100.0;
    return CampusEdge(
      from: map['from'] as String,
      to: map['to'] as String,
      weightPx: weight,
      type: map['type'] as String? ?? 'corridor',
      wheelchair: map['wheelchair'] as bool? ?? true,
    );
  }
}

class CampusMap {
  /// Resolusi standar gambar denah PNG (16:9).
  static const double canvasWidth = 2000.0;
  static const double canvasHeight = 1125.0;

  final String buildingName;
  final List<int> floors;
  final double? scaleMetersPerPx;

  /// Semua node termasuk junction, lift, tangga (dipakai oleh algoritma Dijkstra).
  final List<CampusLocation> allNodes;

  /// Daftar ruangan tujuan (hanya type == 'room', tanpa lift/tangga/junction).
  final List<CampusLocation> locations;

  /// Daftar lokasi awal yang valid: Pintu Masuk (entrance) + Ruangan (room).
  final List<CampusLocation> startLocations;

  /// Gabungan edges koridor + interfloor_edges (lift & tangga).
  final List<CampusEdge> edges;

  final Map<String, CampusLocation> _nodeIndex;
  String? selectedLocationId;

  CampusMap({
    required this.locations,
    this.buildingName = 'Gedung G1',
    this.floors = const [1, 2, 3, 4, 5],
    this.scaleMetersPerPx,
    List<CampusLocation>? allNodes,
    List<CampusLocation>? startLocations,
    this.edges = const [],
    this.selectedLocationId,
  })  : allNodes = allNodes ?? locations,
        startLocations = startLocations ?? locations,
        _nodeIndex = {
          for (final n in (allNodes ?? locations)) n.id: n,
        };

  /// buildAccessibleMap(mapData) pada sequence diagram UC-05.
  static CampusMap buildAccessibleMap(Map<String, dynamic> mapData) {
    final buildingRaw = mapData['building'] as String?;
    final buildingName =
        buildingRaw == null ? 'Gedung G1' : 'Gedung $buildingRaw';
    final scale = (mapData['scale_m_per_px'] as num?)?.toDouble();

    final rawNodes = (mapData['nodes'] as List<dynamic>?) ??
        (mapData['locations'] as List<dynamic>?) ??
        const [];
    final rawNodeMaps = rawNodes
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Deteksi lantai mana saja yang memiliki lift dan akses ramp.
    final floorsWithLift = <int>{};
    final floorsWithRamp = <int>{};
    for (final m in rawNodeMaps) {
      final floor = (m['floor'] as num?)?.toInt() ?? 1;
      final type = m['type'] as String? ?? 'room';
      final id = m['id'] as String? ?? '';
      final name = (m['name'] as String? ?? '').toLowerCase();
      if (type == 'lift') floorsWithLift.add(floor);
      if (id == 'G1-L1-E_SMP' || name.contains('ramp')) {
        floorsWithRamp.add(floor);
      }
    }

    final allNodes = rawNodeMaps
        .map(
          (m) {
            final floor = (m['floor'] as num?)?.toInt() ?? 1;
            return CampusLocation.fromMap(
              m,
              defaultBuilding: buildingName,
              floorHasLift: floorsWithLift.contains(floor),
              floorHasRamp: floorsWithRamp.contains(floor),
            );
          },
        )
        .toList();

    // Tujuan & daftar utama hanya berisi ruangan (tanpa lift, tangga, junction).
    final roomLocations = allNodes.where((n) => n.isRoom).toList();

    // Titik awal boleh dari pintu masuk (entrance) maupun ruangan.
    final entrances = allNodes.where((n) => n.isEntrance).toList();
    final startLocations = [...entrances, ...roomLocations];

    final rawEdges = [
      ...(mapData['edges'] as List<dynamic>? ?? const []),
      ...(mapData['interfloor_edges'] as List<dynamic>? ?? const []),
    ];
    final edges = rawEdges
        .map((e) => CampusEdge.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawFloors = (mapData['floors'] as List<dynamic>? ?? const [])
        .map((e) => (e as num).toInt())
        .toList()
      ..sort();

    return CampusMap(
      buildingName: buildingName,
      floors: rawFloors.isEmpty ? const [1] : rawFloors,
      scaleMetersPerPx: scale,
      allNodes: allNodes,
      locations: roomLocations,
      startLocations: startLocations,
      edges: edges,
    );
  }

  CampusLocation? nodeById(String id) => _nodeIndex[id];

  CampusLocation? get selectedLocation =>
      selectedLocationId == null ? null : _nodeIndex[selectedLocationId!];

  /// saveSelectedLocation(locationId) pada sequence diagram UC-05.
  void saveSelectedLocation(String locationId) {
    selectedLocationId = locationId;
  }

  /// Mencari node terdekat pada lantai tertentu dari posisi ternormalisasi (x, y).
  CampusLocation? nearestNode({
    required double normX,
    required double normY,
    required int floor,
    bool wheelchairOnly = false,
    bool namedOnly = false,
  }) {
    final px = normX * canvasWidth;
    final py = normY * canvasHeight;

    CampusLocation? best;
    double bestDistSq = double.infinity;

    for (final node in allNodes) {
      if (node.floor != floor) continue;
      if (wheelchairOnly && !node.isWheelchairAccessible) continue;
      if (namedOnly && node.isJunction) continue;

      final dx = node.pixelX - px;
      final dy = node.pixelY - py;
      final dSq = dx * dx + dy * dy;
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        best = node;
      }
    }
    return best;
  }

  /// Mencari jarak piksel antara dua koordinat ternormalisasi.
  static double distancePx(double x1, double y1, double x2, double y2) {
    final dx = (x2 - x1) * canvasWidth;
    final dy = (y2 - y1) * canvasHeight;
    return math.sqrt(dx * dx + dy * dy);
  }
}
