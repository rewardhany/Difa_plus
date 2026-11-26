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

    expect(campusMap.startLocations.any((l) => l.type == 'entrance'), isTrue);
    expect(
      campusMap.startLocations.every((l) => l.isEntrance || l.isRoom),
      isTrue,
    );
  });

  test('ruang Emergency punya simpang koridor J_EMG & node EMG tepat di pintu alcove', () {
    for (int f = 1; f <= 5; f++) {
      final jEmg = campusMap.nodeById('G1-L$f-J_EMG');
      final emg = campusMap.nodeById('G1-L$f-EMG');
      expect(jEmg, isNotNull);
      expect(emg, isNotNull);
      // Pintu Emergency berada lebih atas (pixelY lebih kecil) dari koridor utama
      expect(emg!.pixelY, lessThan(jEmg!.pixelY - 80));
    }

    // Rute koridor dari Ruang Prodi RPL ke Toilet TIDAK boleh masuk ke node EMG
    final corridorRoute = RouteFinder.findRoute(
      map: campusMap,
      startId: 'G1-L1-R005',
      endId: 'G1-L1-TOI',
      wheelchairOnly: true,
    );
    expect(corridorRoute, isNotNull);
    expect(corridorRoute!.path.any((n) => n.id == 'G1-L1-EMG'), isFalse);
    expect(corridorRoute.path.any((n) => n.id == 'G1-L1-J_EMG'), isTrue);

    // Rute menuju Emergency masuk melalui J_EMG ke EMG
    final toEmgRoute = RouteFinder.findRoute(
      map: campusMap,
      startId: 'G1-L1-R005',
      endId: 'G1-L1-EMG',
      wheelchairOnly: true,
    );
    expect(toEmgRoute, isNotNull);
    expect(toEmgRoute!.path.last.id, equals('G1-L1-EMG'));
    expect(toEmgRoute.path[toEmgRoute.path.length - 2].id, equals('G1-L1-J_EMG'));
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

  test('simulasi pindah lantai otomatis 1 detik pada Lift tanpa menekan tombol', () async {
    final controller = MapController(mapsService: _FileMapsService());
    await controller.showCampusMap();
    controller.ensureDefaultStart(wheelchairOnly: true);

    controller.setSelectedLocation('G1-L4-R007');
    expect(controller.calculateRoute(wheelchairOnly: true), isTrue);

    // Geser joystick ke node Lift di Lantai 1
    final transfer = controller.activeRoute!.transfersOnFloor(1).first;
    expect(transfer.edgeType, equals('lift'));
    controller.moveStudentBy(
      transfer.fromNode.x - controller.simX,
      transfer.fromNode.y - controller.simY,
    );

    // Timer tunggu 1 detik harus aktif otomatis
    expect(controller.isWaitingFloorTransfer, isTrue);
    expect(controller.simFloor, equals(1));

    // Tunggu sedikit lebih dari 1 detik -> lantai otomatis berpindah ke Lantai 4!
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    expect(controller.simFloor, equals(4));
    expect(controller.activeFloor, equals(4));
    expect(controller.isWaitingFloorTransfer, isFalse);

    // Geser ke tujuan Perpustakaan di Lantai 4
    final dest = controller.activeRoute!.end;
    controller.moveStudentBy(dest.x - controller.simX, dest.y - controller.simY);
    expect(controller.routeProgress!.hasArrived, isTrue);
    expect(controller.routeProgress!.progressPercent, equals(100));

    controller.dispose();
  });

  test('simulasi pindah lantai otomatis 1 detik di ujung Tangga untuk non-kursi-roda/netra', () async {
    final controller = MapController(mapsService: _FileMapsService());
    await controller.showCampusMap();
    controller.ensureDefaultStart(wheelchairOnly: false);
    controller.setVerticalAccessMode(
      VerticalAccessMode.stairsPreferred,
      wheelchairOnly: false,
    );

    controller.setSelectedLocation('G1-L2-R007');
    expect(controller.calculateRoute(wheelchairOnly: false), isTrue);

    final transfer = controller.activeRoute!.transfersOnFloor(1).first;
    expect(transfer.edgeType, equals('stairs'));
    expect(transfer.toFloor, equals(2));
    // Node ujung tangga berada di dalam kotak tangga (jauh di kiri/kanan koridor)
    expect(transfer.fromNode.pixelX, lessThan(500));

    // Geser joystick masuk ke ujung tangga
    controller.moveStudentBy(
      transfer.fromNode.x - controller.simX,
      transfer.fromNode.y - controller.simY,
    );
    expect(controller.isWaitingFloorTransfer, isTrue);

    // Tunggu 1 detik -> otomatis pindah ke Lantai 2!
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    expect(controller.simFloor, equals(2));
    expect(controller.activeFloor, equals(2));
    // Naik dari tangga bawah Lt 1 harus muncul di tangga ATAS Lt 2 (STR_*T)
    expect(transfer.fromNode.id, endsWith('B'));
    expect(transfer.targetNode.id, endsWith('T'));

    controller.dispose();
  });

  test('arah tangga lintas lantai: naik selalu dari tangga bawah -> muncul tangga atas, turun sebaliknya', () {
    // Naik Lt 1 -> Lt 4 via Tangga
    final upRoute = RouteFinder.findRoute(
      map: campusMap,
      startId: 'G1-L1-E_UTM',
      endId: 'G1-L4-R005',
      wheelchairOnly: false,
      verticalMode: VerticalAccessMode.stairsPreferred,
    );
    expect(upRoute, isNotNull);
    for (int f = 1; f <= 3; f++) {
      final t = upRoute!.transfersOnFloor(f).first;
      expect(t.toFloor, equals(f + 1));
      expect(t.fromNode.id, endsWith('B'), reason: 'Naik dari Lt $f harus lewat tangga bawah');
      expect(t.targetNode.id, endsWith('T'), reason: 'Muncul di Lt ${f + 1} harus di tangga atas');
    }

    // Turun Lt 4 -> Lt 1 via Tangga
    final downRoute = RouteFinder.findRoute(
      map: campusMap,
      startId: 'G1-L4-R005',
      endId: 'G1-L1-R005',
      wheelchairOnly: false,
      verticalMode: VerticalAccessMode.stairsPreferred,
    );
    expect(downRoute, isNotNull);
    for (int f = 4; f >= 2; f--) {
      final t = downRoute!.transfersOnFloor(f).first;
      expect(t.toFloor, equals(f - 1));
      expect(t.fromNode.id, endsWith('T'), reason: 'Turun dari Lt $f harus lewat tangga atas');
      expect(t.targetNode.id, endsWith('B'), reason: 'Muncul di Lt ${f - 1} harus di tangga bawah');
    }
  });
}
