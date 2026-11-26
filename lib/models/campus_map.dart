/// Entity: CampusMap (+ CampusLocation)
/// Dipakai pada UC-05 Show Campus Maps, lalu UC-06, UC-07, UC-08.
///
/// Sesuai Sequence Diagram UC-05: CampusMap bertugas menyusun denah
/// aksesibel (buildAccessibleMap) dan menyimpan lokasi terpilih
/// (saveSelectedLocation) supaya bisa dipakai UC-06 lewat <<include>>.
library;

class CampusLocation {
  final String id;
  final String name;
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
  });

  /// Ramah kursi roda jika bukan tangga dan bukan Pintu Utama (Tangga).
  bool get isWheelchairAccessible => type != 'stairs' && id != 'G1-L1-E_UTM';

  factory CampusLocation.fromMap(
    Map<String, dynamic> map, {
    String defaultBuilding = 'Gedung G1',
    double canvasWidth = CampusMap.canvasWidth,
    double canvasHeight = CampusMap.canvasHeight,
  }) {
    final id = map['id'] as String;
    final name = map['name'] as String? ?? 'Lokasi';
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
    final hasRamp = (map['hasRamp'] as bool?) ??
        (lowerName.contains('ramp') || id == 'G1-L1-E_SMP');
    final hasLift = (map['hasLift'] as bool?) ?? (type == 'lift');
    final hasAccessibleToilet = (map['hasAccessibleToilet'] as bool?) ??
        lowerName.contains('toilet');

    final wheelchairOk = type != 'stairs' && id != 'G1-L1-E_UTM';
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

  /// Semua node termasuk junction (dipakai oleh algoritma Dijkstra).
  final List<CampusLocation> allNodes;

  /// Lokasi yang tampil di daftar & peta (tanpa junction simpang koridor).
  final List<CampusLocation> locations;

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
    this.edges = const [],
    this.selectedLocationId,
  })  : allNodes = allNodes ?? locations,
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
    final allNodes = rawNodes
        .map(
          (e) => CampusLocation.fromMap(
            Map<String, dynamic>.from(e as Map),
            defaultBuilding: buildingName,
          ),
        )
        .toList();

    final visibleLocations =
        allNodes.where((n) => n.type != 'junction').toList();

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
      locations: visibleLocations,
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
}
