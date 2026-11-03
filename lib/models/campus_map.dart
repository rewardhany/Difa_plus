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

  /// Posisi relatif di denah, rentang 0.0 - 1.0 (bukan koordinat GPS).
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
    required this.x,
    required this.y,
    required this.audioDescription,
    this.hasRamp = false,
    this.hasLift = false,
    this.hasAccessibleToilet = false,
  });

  bool get isWheelchairAccessible => hasRamp || hasLift;

  factory CampusLocation.fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String? ?? 'Lokasi';
    return CampusLocation(
      id: map['id'] as String,
      name: name,
      building: map['building'] as String? ?? '',
      floor: (map['floor'] as num?)?.toInt() ?? 1,
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      audioDescription: map['audioDescription'] as String? ?? name,
      hasRamp: map['hasRamp'] as bool? ?? false,
      hasLift: map['hasLift'] as bool? ?? false,
      hasAccessibleToilet: map['hasAccessibleToilet'] as bool? ?? false,
    );
  }
}

class CampusMap {
  final List<CampusLocation> locations;
  String? selectedLocationId;

  CampusMap({required this.locations, this.selectedLocationId});

  /// buildAccessibleMap(mapData) pada sequence diagram UC-05.
  static CampusMap buildAccessibleMap(Map<String, dynamic> mapData) {
    final raw = (mapData['locations'] as List<dynamic>? ?? []);
    final locations = raw
        .map((e) => CampusLocation.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return CampusMap(locations: locations);
  }

  CampusLocation? get selectedLocation {
    for (final location in locations) {
      if (location.id == selectedLocationId) return location;
    }
    return null;
  }

  /// saveSelectedLocation(locationId) pada sequence diagram UC-05.
  void saveSelectedLocation(String locationId) {
    selectedLocationId = locationId;
  }
}
