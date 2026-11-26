import 'dart:math' as math;
import 'campus_map.dart';

/// Satu baris instruksi teks pada hasil navigasi (UC-06).
class RouteStep {
  final int floor;
  final int? targetFloor;
  final bool isFloorChange;
  final double distanceMeters;
  final String instruction;

  const RouteStep({
    required this.floor,
    required this.instruction,
    this.targetFloor,
    this.isFloorChange = false,
    this.distanceMeters = 0,
  });
}

/// Entity: CampusRoute (UC-06 Get Campus Route).
/// Menyimpan urutan node, edge, daftar instruksi, dan total jarak rute.
class CampusRoute {
  final List<CampusLocation> path;
  final List<CampusEdge> edges;
  final List<RouteStep> steps;
  final double totalDistanceMeters;
  final bool wheelchairOnly;
  final List<int> floorsInvolved;

  const CampusRoute({
    required this.path,
    required this.edges,
    required this.steps,
    required this.totalDistanceMeters,
    required this.wheelchairOnly,
    required this.floorsInvolved,
  });

  CampusLocation get start => path.first;
  CampusLocation get end => path.last;
}

/// Mesin pencari rute terpendek (Dijkstra) lintas lantai untuk graf Gedung G1.
class RouteFinder {
  RouteFinder._();

  /// Estimasi default: 100 px ≈ 5 meter (0.05 m/px) saat scale_m_per_px null.
  static const double defaultMetersPerPx = 0.05;

  static CampusRoute? findRoute({
    required CampusMap map,
    required String startId,
    required String endId,
    required bool wheelchairOnly,
  }) {
    final startNode = map.nodeById(startId);
    final endNode = map.nodeById(endId);
    if (startNode == null || endNode == null) return null;

    if (startId == endId) {
      return CampusRoute(
        path: [startNode],
        edges: const [],
        steps: [
          RouteStep(
            floor: startNode.floor,
            instruction:
                'Anda sudah berada di ${startNode.name} (Lantai ${startNode.floor}).',
          ),
        ],
        totalDistanceMeters: 0,
        wheelchairOnly: wheelchairOnly,
        floorsInvolved: [startNode.floor],
      );
    }

    // 1. Bangun adjacency list dua arah (undirected graph).
    final Map<String, List<_AdjEntry>> graph = {};
    for (final edge in map.edges) {
      if (wheelchairOnly && !edge.wheelchair) continue;
      graph.putIfAbsent(edge.from, () => []).add(_AdjEntry(edge.to, edge));
      graph.putIfAbsent(edge.to, () => []).add(_AdjEntry(edge.from, edge));
    }

    // 2. Jalankan Dijkstra.
    final Map<String, double> dist = {startId: 0};
    final Map<String, String> prevNode = {};
    final Map<String, CampusEdge> prevEdge = {};
    final Set<String> visited = {};
    final Set<String> unvisited = {startId};

    while (unvisited.isNotEmpty) {
      String? current;
      double bestDist = double.infinity;
      for (final id in unvisited) {
        final d = dist[id] ?? double.infinity;
        if (d < bestDist) {
          bestDist = d;
          current = id;
        }
      }

      if (current == null || bestDist == double.infinity) break;
      if (current == endId) break;

      unvisited.remove(current);
      visited.add(current);

      for (final neighbor in graph[current] ?? const <_AdjEntry>[]) {
        if (visited.contains(neighbor.targetId)) continue;
        final alt = bestDist + neighbor.edge.weightPx;
        if (alt < (dist[neighbor.targetId] ?? double.infinity)) {
          dist[neighbor.targetId] = alt;
          prevNode[neighbor.targetId] = current;
          prevEdge[neighbor.targetId] = neighbor.edge;
          unvisited.add(neighbor.targetId);
        }
      }
    }

    if (!prevNode.containsKey(endId)) return null;

    // 3. Rekonstruksi urutan node & edge dari belakang ke depan.
    final List<CampusLocation> path = [];
    final List<CampusEdge> pathEdges = [];
    String cursor = endId;
    while (cursor != startId) {
      final node = map.nodeById(cursor);
      final edge = prevEdge[cursor];
      final parent = prevNode[cursor];
      if (node == null || edge == null || parent == null) return null;
      path.add(node);
      pathEdges.add(edge);
      cursor = parent;
    }
    path.add(startNode);

    final orderedPath = path.reversed.toList();
    final orderedEdges = pathEdges.reversed.toList();

    final scale = map.scaleMetersPerPx ?? defaultMetersPerPx;
    final steps = _buildSteps(orderedPath, orderedEdges, scale);

    double totalMeters = 0;
    for (int i = 0; i < orderedEdges.length; i++) {
      if (orderedPath[i].floor == orderedPath[i + 1].floor) {
        totalMeters += orderedEdges[i].weightPx * scale;
      }
    }

    final floors = <int>[];
    for (final node in orderedPath) {
      if (!floors.contains(node.floor)) floors.add(node.floor);
    }

    return CampusRoute(
      path: orderedPath,
      edges: orderedEdges,
      steps: steps,
      totalDistanceMeters: totalMeters,
      wheelchairOnly: wheelchairOnly,
      floorsInvolved: floors,
    );
  }

  /// Mengubah urutan node menjadi instruksi teks yang rapi & mudah dibaca
  /// (menggabungkan koridor lurus dan perjalanan lift/tangga berturut-turut).
  static List<RouteStep> _buildSteps(
    List<CampusLocation> path,
    List<CampusEdge> edges,
    double scale,
  ) {
    final steps = <RouteStep>[
      RouteStep(
        floor: path.first.floor,
        instruction: 'Mulai dari ${path.first.name} (Lantai ${path.first.floor}).',
      ),
    ];

    double? prevDx;
    double? prevDy;
    int i = 0;

    while (i < edges.length) {
      final from = path[i];
      final to = path[i + 1];
      final edge = edges[i];

      // A. Perpindahan antar lantai (Lift atau Tangga)
      if (from.floor != to.floor) {
        final startFloor = from.floor;
        final facilityName = from.name;
        final edgeType = edge.type;
        int j = i;
        while (j < edges.length &&
            path[j].floor != path[j + 1].floor &&
            edges[j].type == edgeType) {
          j++;
        }
        final endFloor = path[j].floor;
        final arah = endFloor > startFloor ? 'naik' : 'turun';
        steps.add(
          RouteStep(
            floor: startFloor,
            targetFloor: endFloor,
            isFloorChange: true,
            instruction:
                'Gunakan $facilityName untuk $arah dari Lantai $startFloor ke Lantai $endFloor.',
          ),
        );
        prevDx = null;
        prevDy = null;
        i = j;
        continue;
      }

      // B. Pergerakan di lantai yang sama (gabungkan segmen yang searah)
      final dx = to.pixelX - from.pixelX;
      final dy = to.pixelY - from.pixelY;

      String turnPrefix = '';
      if (prevDx != null && prevDy != null) {
        // Sistem koordinat layar (+x kanan, +y bawah):
        // cross > 0 = belok kanan, cross < 0 = belok kiri.
        final cross = prevDx * dy - prevDy * dx;
        final dot = prevDx * dx + prevDy * dy;
        final angle = math.atan2(cross, dot);
        if (angle > 0.40) {
          turnPrefix = 'Belok kanan, lalu ';
        } else if (angle < -0.40) {
          turnPrefix = 'Belok kiri, lalu ';
        }
      }

      double segPx = edge.weightPx;
      double lastDx = dx;
      double lastDy = dy;
      final edgeType = edge.type;
      int j = i + 1;

      while (j < edges.length) {
        final nextFrom = path[j];
        final nextTo = path[j + 1];
        final nextEdge = edges[j];
        if (nextFrom.floor != nextTo.floor || nextEdge.type != edgeType) break;

        final ndx = nextTo.pixelX - nextFrom.pixelX;
        final ndy = nextTo.pixelY - nextFrom.pixelY;
        final cross = lastDx * ndy - lastDy * ndx;
        final dot = lastDx * ndx + lastDy * ndy;
        final angle = math.atan2(cross, dot);
        if (angle.abs() >= 0.40) break;

        segPx += nextEdge.weightPx;
        lastDx = ndx;
        lastDy = ndy;
        j++;
      }

      final destNode = path[j];
      final meters = (segPx * scale).round();
      final distText = meters <= 1 ? 'sekitar 1 meter' : 'sekitar $meters meter';
      final action = edgeType == 'stairs' ? 'lewati tangga' : 'jalan lurus';
      final rawText = '$turnPrefix$action $distText menuju ${destNode.name}.';
      final formatted = rawText[0].toUpperCase() + rawText.substring(1);

      steps.add(
        RouteStep(
          floor: from.floor,
          distanceMeters: segPx * scale,
          instruction: formatted,
        ),
      );

      prevDx = lastDx;
      prevDy = lastDy;
      i = j;
    }

    steps.add(
      RouteStep(
        floor: path.last.floor,
        instruction:
            'Tiba di tujuan: ${path.last.name} (Lantai ${path.last.floor}).',
      ),
    );

    return steps;
  }
}

class _AdjEntry {
  final String targetId;
  final CampusEdge edge;

  const _AdjEntry(this.targetId, this.edge);
}