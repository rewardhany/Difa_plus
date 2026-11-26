import 'dart:math' as math;
import 'campus_map.dart';

double _hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

/// Preferensi akses antar lantai untuk pengguna non-kursi-roda.
enum VerticalAccessMode { auto, liftOnly, stairsPreferred }

/// Satu baris instruksi teks pada hasil navigasi (UC-06).
class RouteStep {
  final int floor;
  final int? targetFloor;
  final bool isFloorChange;
  final double distanceMeters;
  final String instruction;
  final int startPathIndex;
  final int endPathIndex;

  const RouteStep({
    required this.floor,
    required this.instruction,
    this.targetFloor,
    this.isFloorChange = false,
    this.distanceMeters = 0,
    this.startPathIndex = 0,
    this.endPathIndex = 0,
  });
}

/// Informasi perpindahan lantai saat mahasiswa simulasi berada di dekat Lift/Tangga rute.
class FloorTransferPrompt {
  final int fromFloor;
  final int toFloor;
  final String facilityName;
  final String edgeType; // 'lift' atau 'stairs'
  final CampusLocation fromNode;
  final CampusLocation targetNode;
  final int fromPathIndex;
  final int targetPathIndex;

  const FloorTransferPrompt({
    required this.fromFloor,
    required this.toFloor,
    required this.facilityName,
    required this.edgeType,
    required this.fromNode,
    required this.targetNode,
    required this.fromPathIndex,
    required this.targetPathIndex,
  });

  String get directionWord => toFloor > fromFloor ? 'Naik' : 'Turun';

  String get actionLabel => '$directionWord $facilityName ke Lt $toFloor';
}

/// Hasil evaluasi posisi mahasiswa simulasi terhadap rute aktif ("sudah sampai mana").
class RouteProgress {
  final double progressRatio; // 0.0 - 1.0
  final double distanceCoveredMeters;
  final double remainingDistanceMeters;
  final int currentSegmentIndex;
  final double segmentT; // 0.0 - 1.0 pada segmen saat ini
  final int currentStepIndex;
  final bool isOffRoute;
  final bool hasArrived;
  final double distanceFromRoutePx;
  final FloorTransferPrompt? pendingTransfer;
  final double? pendingTransferDistancePx;

  const RouteProgress({
    required this.progressRatio,
    required this.distanceCoveredMeters,
    required this.remainingDistanceMeters,
    required this.currentSegmentIndex,
    required this.segmentT,
    required this.currentStepIndex,
    required this.isOffRoute,
    required this.hasArrived,
    required this.distanceFromRoutePx,
    this.pendingTransfer,
    this.pendingTransferDistancePx,
  });

  int get progressPercent => (progressRatio * 100).round().clamp(0, 100);
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
  final double scaleMetersPerPx;

  const CampusRoute({
    required this.path,
    required this.edges,
    required this.steps,
    required this.totalDistanceMeters,
    required this.wheelchairOnly,
    required this.floorsInvolved,
    this.scaleMetersPerPx = RouteFinder.defaultMetersPerPx,
  });

  CampusLocation get start => path.first;
  CampusLocation get end => path.last;

  /// Semua node rute yang berada di lantai tertentu (tanpa duplikasi berurutan).
  List<CampusLocation> nodesOnFloor(int floor) =>
      path.where((n) => n.floor == floor).toList();

  /// Daftar perpindahan lantai (Lift/Tangga) yang berangkat dari lantai tertentu.
  List<FloorTransferPrompt> transfersOnFloor(int floor) =>
      _collectTransfers().where((t) => t.fromFloor == floor).toList();

  /// Daftar titik keluar Lift/Tangga yang tiba di lantai tertentu.
  List<FloorTransferPrompt> incomingTransfersOnFloor(int floor) =>
      _collectTransfers().where((t) => t.toFloor == floor).toList();

  List<FloorTransferPrompt> _collectTransfers() {
    final result = <FloorTransferPrompt>[];
    int i = 0;
    while (i < edges.length) {
      final a = path[i];
      final b = path[i + 1];
      if (a.floor != b.floor) {
        final edgeType = edges[i].type;
        int j = i;
        while (j < edges.length &&
            path[j].floor != path[j + 1].floor &&
            edges[j].type == edgeType) {
          j++;
        }
        final fromNode = path[i];
        final toNode = path[j];
        result.add(
          FloorTransferPrompt(
            fromFloor: fromNode.floor,
            toFloor: toNode.floor,
            facilityName: fromNode.name,
            edgeType: edgeType,
            fromNode: fromNode,
            targetNode: toNode,
            fromPathIndex: i,
            targetPathIndex: j,
          ),
        );
        i = j;
        continue;
      }
      i++;
    }
    return result;
  }

  /// Mengevaluasi posisi mahasiswa simulasi (normX, normY, floor) terhadap rute ini.
  RouteProgress evaluateProgress({
    required double normX,
    required double normY,
    required int floor,
  }) {
    final px = normX * CampusMap.canvasWidth;
    final py = normY * CampusMap.canvasHeight;

    // Kasus khusus: titik awal == tujuan
    if (edges.isEmpty) {
      final dEnd = _hypot(px - end.pixelX, py - end.pixelY);
      final arrived = floor == end.floor && dEnd <= 55.0;
      return RouteProgress(
        progressRatio: arrived ? 1.0 : 0.0,
        distanceCoveredMeters: 0,
        remainingDistanceMeters: 0,
        currentSegmentIndex: 0,
        segmentT: 1.0,
        currentStepIndex: 0,
        isOffRoute: floor != end.floor || dEnd > 95.0,
        hasArrived: arrived,
        distanceFromRoutePx: floor == end.floor ? dEnd : double.infinity,
      );
    }

    // Bobot progres total (koridor + bobot visual kecil untuk pindah lantai)
    const double transferProgressWeight = 60.0;
    final segWeights = <double>[];
    final segMeters = <double>[];
    double totalWeight = 0;
    for (int i = 0; i < edges.length; i++) {
      final sameFloor = path[i].floor == path[i + 1].floor;
      final w = sameFloor ? edges[i].weightPx : transferProgressWeight;
      final m = sameFloor ? edges[i].weightPx * scaleMetersPerPx : 0.0;
      segWeights.add(w);
      segMeters.add(m);
      totalWeight += w;
    }

    // Cek apakah sudah tiba di tujuan
    final distToEnd = floor == end.floor
        ? _hypot(px - end.pixelX, py - end.pixelY)
        : double.infinity;
    final hasArrived = floor == end.floor && distToEnd <= 45.0;

    if (hasArrived) {
      return RouteProgress(
        progressRatio: 1.0,
        distanceCoveredMeters: totalDistanceMeters,
        remainingDistanceMeters: 0,
        currentSegmentIndex: edges.length,
        segmentT: 1.0,
        currentStepIndex: steps.length - 1,
        isOffRoute: false,
        hasArrived: true,
        distanceFromRoutePx: distToEnd,
      );
    }

    // Cek apakah berada di dekat titik pindah lantai (Lift/Tangga) pada rute aktif
    FloorTransferPrompt? pendingTransfer;
    double bestTransferDist = double.infinity;
    for (final t in transfersOnFloor(floor)) {
      final d = _hypot(px - t.fromNode.pixelX, py - t.fromNode.pixelY);
      if (d <= 65.0 && d < bestTransferDist) {
        bestTransferDist = d;
        pendingTransfer = t;
      }
    }

    // Proyeksikan posisi (px, py) ke semua segmen di lantai saat ini
    int bestSegIdx = -1;
    double bestT = 0.0;
    double bestDistPx = double.infinity;

    for (int i = 0; i < edges.length; i++) {
      final a = path[i];
      final b = path[i + 1];
      if (a.floor != floor || b.floor != floor) continue;

      final abx = b.pixelX - a.pixelX;
      final aby = b.pixelY - a.pixelY;
      final lenSq = abx * abx + aby * aby;
      double t = 0.0;
      if (lenSq > 1e-6) {
        t = ((px - a.pixelX) * abx + (py - a.pixelY) * aby) / lenSq;
        t = t.clamp(0.0, 1.0);
      }
      final qx = a.pixelX + t * abx;
      final qy = a.pixelY + t * aby;
      final d = _hypot(px - qx, py - qy);

      if (d < bestDistPx) {
        bestDistPx = d;
        bestSegIdx = i;
        bestT = t;
      }
    }

    // Cadangan: jika di lantai ini hanya ada node tunggal (mis. titik transfer/ujung)
    if (bestSegIdx == -1) {
      for (int i = 0; i < path.length; i++) {
        if (path[i].floor != floor) continue;
        final d = _hypot(px - path[i].pixelX, py - path[i].pixelY);
        if (d < bestDistPx) {
          bestDistPx = d;
          bestSegIdx = math.min(i, edges.length - 1);
          bestT = i >= edges.length ? 1.0 : 0.0;
        }
      }
    }

    // Jika mahasiswa berada di lantai yang bahkan tidak dilewati rute
    if (bestSegIdx == -1) {
      return RouteProgress(
        progressRatio: 0.0,
        distanceCoveredMeters: 0,
        remainingDistanceMeters: totalDistanceMeters,
        currentSegmentIndex: 0,
        segmentT: 0.0,
        currentStepIndex: 0,
        isOffRoute: true,
        hasArrived: false,
        distanceFromRoutePx: double.infinity,
      );
    }

    // Jika mahasiswa tepat di titik transfer lantai, pakai indeks transfer
    int effectiveSegIdx = bestSegIdx;
    double effectiveT = bestT;
    if (pendingTransfer != null && bestTransferDist <= 42.0) {
      effectiveSegIdx = pendingTransfer.fromPathIndex;
      effectiveT = 0.0;
    }

    double coveredWeight = 0;
    double coveredMeters = 0;
    for (int i = 0; i < effectiveSegIdx; i++) {
      coveredWeight += segWeights[i];
      coveredMeters += segMeters[i];
    }
    if (effectiveSegIdx < edges.length) {
      coveredWeight += segWeights[effectiveSegIdx] * effectiveT;
      coveredMeters += segMeters[effectiveSegIdx] * effectiveT;
    }

    final ratio = totalWeight > 0
        ? (coveredWeight / totalWeight).clamp(0.0, 1.0)
        : 0.0;
    final remainingMeters =
        math.max(0.0, totalDistanceMeters - coveredMeters);
    final isOffRoute = bestDistPx > 95.0;

    // Tentukan step instruksi aktif berdasarkan segmen saat ini
    int activeStepIdx = 0;
    if (pendingTransfer != null) {
      for (int s = 0; s < steps.length; s++) {
        if (steps[s].isFloorChange &&
            steps[s].startPathIndex == pendingTransfer.fromPathIndex) {
          activeStepIdx = s;
          break;
        }
      }
    } else {
      for (int s = 1; s < steps.length - 1; s++) {
        final step = steps[s];
        if (effectiveSegIdx >= step.startPathIndex &&
            effectiveSegIdx < step.endPathIndex) {
          activeStepIdx = s;
          break;
        }
      }
      // Jika masih di awal banget (dekat titik awal), arahkan ke step 1 (instruksi gerak pertama)
      if (activeStepIdx == 0 && steps.length > 2) {
        activeStepIdx = 1;
      }
    }

    return RouteProgress(
      progressRatio: ratio,
      distanceCoveredMeters: coveredMeters,
      remainingDistanceMeters: remainingMeters,
      currentSegmentIndex: effectiveSegIdx,
      segmentT: effectiveT,
      currentStepIndex: activeStepIdx,
      isOffRoute: isOffRoute,
      hasArrived: false,
      distanceFromRoutePx: bestDistPx,
      pendingTransfer: pendingTransfer,
      pendingTransferDistancePx:
          pendingTransfer != null ? bestTransferDist : null,
    );
  }
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
    VerticalAccessMode verticalMode = VerticalAccessMode.auto,
  }) {
    final startNode = map.nodeById(startId);
    final endNode = map.nodeById(endId);
    if (startNode == null || endNode == null) return null;

    final effectiveMode =
        wheelchairOnly ? VerticalAccessMode.liftOnly : verticalMode;
    final scale = map.scaleMetersPerPx ?? defaultMetersPerPx;

    if (startId == endId) {
      return CampusRoute(
        path: [startNode],
        edges: const [],
        steps: [
          RouteStep(
            floor: startNode.floor,
            instruction:
                'Anda sudah berada di ${startNode.name} (Lantai ${startNode.floor}).',
            startPathIndex: 0,
            endPathIndex: 0,
          ),
        ],
        totalDistanceMeters: 0,
        wheelchairOnly: wheelchairOnly,
        floorsInvolved: [startNode.floor],
        scaleMetersPerPx: scale,
      );
    }

    // 1. Bangun adjacency list dua arah (undirected graph).
    final Map<String, List<_AdjEntry>> graph = {};
    for (final edge in map.edges) {
      if (wheelchairOnly && !edge.wheelchair) continue;

      final fromNode = map.nodeById(edge.from);
      final toNode = map.nodeById(edge.to);
      final touchesStairsNode =
          fromNode?.type == 'stairs' || toNode?.type == 'stairs';
      final touchesLiftNode =
          fromNode?.type == 'lift' || toNode?.type == 'lift';

      if (effectiveMode == VerticalAccessMode.liftOnly && touchesStairsNode) {
        continue;
      }
      if (effectiveMode == VerticalAccessMode.stairsPreferred &&
          touchesLiftNode) {
        continue;
      }

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
      scaleMetersPerPx: scale,
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
        startPathIndex: 0,
        endPathIndex: 0,
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
            startPathIndex: i,
            endPathIndex: j,
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
          startPathIndex: i,
          endPathIndex: j,
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
        startPathIndex: path.length - 1,
        endPathIndex: path.length - 1,
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
