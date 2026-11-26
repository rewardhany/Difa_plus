import 'dart:convert';
import 'dart:io';

import 'package:difa_plus/controllers/map_controller.dart';
import 'package:difa_plus/models/campus_map.dart';
import 'package:difa_plus/models/campus_route.dart';
import 'package:difa_plus/services_external/maps_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileMapsService extends MapsService {
  @override
  Future<Map<String, dynamic>?> requestMapData() async {
    final file = File('assets/data/difa_G1_graph.json');
    final raw = await file.readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

void main() {
  late Map<String, dynamic> graphJson;
  late CampusMap campusMap;

  setUpAll(() async {
    final raw = await File('assets/data/difa_G1_graph.json').readAsString();
    graphJson = jsonDecode(raw) as Map<String, dynamic>;
    campusMap = CampusMap.buildAccessibleMap(graphJson);
  });

  test('graf JSON valid dan semua ujung edge terdaftar pada nodes', () {
    for (final edge in campusMap.edges) {
      expect(
        campusMap.nodeById(edge.from),
        isNotNull,
        reason: 'Node asal ${edge.from} tidak ditemukan',
      );
      expect(
        campusMap.nodeById(edge.to),
        isNotNull,
        reason: 'Node tujuan ${edge.to} tidak ditemukan',
      );
    }
  });

  test('daftar ruangan tujuan hanya berisi type room (tanpa lift/tangga/junction)', () {
    expect(campusMap.locations, isNotEmpty);
    for (final loc in campusMap.locations) {
      expect(loc.type, equals('room'));
    }

    // Titik awal berisi pintu masuk + ruangan (tanpa lift/tangga/junction)
    expect(campusMap.startLocations.any((l) => l.type == 'entrance'), isTrue);
    expect(
      campusMap.startLocations.every((l) => l.isEntrance || l.isRoom),
      isTrue,
    );
  });

  test('navigasi lintas lantai ramah kursi roda menggunakan Lift dan bebas Tangga', () {
    final route = RouteFinder.findRoute(
      map: campusMap,
      startId: 'G1-L1-E_SMP',
      endId: 'G1-L4-R007', // Perpustakaan Lt 4
      wheelchairOnly: true,
    );

    expect(route, isNotNull);
    expect(route!.floorsInvolved, containsAllInOrder([1, 4]));
    expect(route.edges.any((e) => e.type == 'stairs'), isFalse);
    expect(route.edges.any((e) => e.type == 'lift'), isTrue);
  });

  test('simulasi mahasiswa: joystick, transfer lantai, progres, dan tiba di tujuan', () async {
    final controller = MapController(mapsService: _FileMapsService());
    await controller.showCampusMap();
    controller.ensureDefaultStart(wheelchairOnly: true);

    expect(controller.hasSimPosition, isTrue);
    expect(controller.simFloor, equals(1));

    // Pilih tujuan Perpustakaan Lt 4 dan hitung rute
    controller.setSelectedLocation('G1-L4-R007');
    final ok = controller.calculateRoute(wheelchairOnly: true);
    expect(ok, isTrue);
    expect(controller.routeProgress, isNotNull);
    expect(controller.routeProgress!.hasArrived, isFalse);
    expect(controller.routeProgress!.progressPercent, lessThan(10));

    // Geser mahasiswa via joystick menuju titik Lift transfer di Lantai 1
    final transfer = controller.activeRoute!.transfersOnFloor(1).first;
    final dxToLift = transfer.fromNode.x - controller.simX;
    final dyToLift = transfer.fromNode.y - controller.simY;
    controller.moveStudentBy(dxToLift, dyToLift);

    expect(controller.routeProgress!.pendingTransfer, isNotNull);
    expect(controller.routeProgress!.pendingTransfer!.toFloor, equals(4));

    // Jalankan perpindahan lantai via Lift
    controller.performPendingFloorTransfer();
    expect(controller.simFloor, equals(4));
    expect(controller.activeFloor, equals(4));
    expect(controller.routeProgress!.progressPercent, greaterThan(20));

    // Geser mahasiswa menuju pintu Perpustakaan di Lantai 4
    final dest = controller.activeRoute!.end;
    controller.moveStudentBy(dest.x - controller.simX, dest.y - controller.simY);

    expect(controller.routeProgress!.hasArrived, isTrue);
    expect(controller.routeProgress!.progressPercent, equals(100));
    expect(controller.routeProgress!.remainingDistanceMeters, equals(0));

    controller.dispose();
  });
}
