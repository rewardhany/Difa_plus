import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SceneVariant { welcome, banner }

/// Ilustrasi sementara (digambar dengan kode) berisi kota, pohon, dan
/// orang dengan berbagai kebutuhan akses. Nanti bisa diganti gambar asli
/// (aset) tanpa mengubah halaman yang memakainya.
class SceneIllustration extends StatelessWidget {
  final SceneVariant variant;

  const SceneIllustration({super.key, this.variant = SceneVariant.welcome});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _ScenePainter(variant),
        size: Size.infinite,
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final SceneVariant variant;

  const _ScenePainter(this.variant);

  static const _building1 = Color(0xFFCFE0F7);
  static const _building2 = Color(0xFFBCD3F1);
  static const _hillLight = Color(0xFF9ED8A8);
  static const _hillDark = Color(0xFF7CC68F);
  static const _treeTrunk = Color(0xFF8B5E3C);
  static const _treeLeaf = Color(0xFF4FAE76);
  static const _skin = Color(0xFFF1C7A5);
  static const _hair = Color(0xFF2B2F3A);
  static const _chair = Color(0xFF334155);
  static const _shoe = Color(0xFF1F2937);
  static const _dogColor = Color(0xFFE0B26B);

  Paint _fill(Color color) => Paint()..color = color;

  void _rr(Canvas c, double l, double t, double w, double h, double r,
      Color color) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
      _fill(color),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.86;
    final welcome = variant == SceneVariant.welcome;

    _clouds(canvas, w, h);
    _skyline(canvas, w, h, ground, welcome);

    canvas.drawOval(
      Rect.fromLTWH(-w * 0.2, ground - h * 0.10, w * 1.4, h * 0.5),
      _fill(_hillLight),
    );
    canvas.drawOval(
      Rect.fromLTWH(-w * 0.1, ground - h * 0.04, w * 1.2, h * 0.4),
      _fill(_hillDark),
    );

    if (welcome) {
      final u = h * 0.05;
      _tree(canvas, w * 0.05, ground, h * 0.08);
      _tree(canvas, w * 0.97, ground, h * 0.08);
      _wheelchairPerson(canvas, w * 0.24, ground, u);
      _standingPerson(
        canvas,
        w * 0.48,
        ground,
        u,
        shirt: const Color(0xFF3B5BDB),
        pants: const Color(0xFF1E293B),
        cane: true,
      );
      _standingPerson(
        canvas,
        w * 0.68,
        ground,
        u,
        shirt: const Color(0xFFC08457),
        pants: const Color(0xFF475569),
        backpack: true,
      );
      _dog(canvas, w * 0.83, ground, u);
    } else {
      final u = h * 0.07;
      _tree(canvas, w * 0.88, ground, h * 0.09);
      _wheelchairPerson(canvas, w * 0.50, ground, u);
    }
  }

  void _clouds(Canvas c, double w, double h) {
    final p = _fill(const Color(0xCCFFFFFF));
    c.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.18, h * 0.12), width: w * 0.22, height: h * 0.07),
      p,
    );
    c.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.28, h * 0.10), width: w * 0.16, height: h * 0.06),
      p,
    );
    c.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.80, h * 0.18), width: w * 0.20, height: h * 0.06),
      p,
    );
  }

  void _skyline(Canvas c, double w, double h, double ground, bool welcome) {
    final List<List<double>> specs = welcome
        ? const [
            [0.04, 0.09, 0.30],
            [0.13, 0.08, 0.44],
            [0.22, 0.11, 0.34],
            [0.62, 0.09, 0.40],
            [0.71, 0.08, 0.52],
            [0.79, 0.11, 0.33],
            [0.90, 0.08, 0.42],
          ]
        : const [
            [0.05, 0.12, 0.40],
            [0.18, 0.10, 0.55],
            [0.30, 0.14, 0.35],
            [0.78, 0.12, 0.45],
          ];
    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      c.drawRect(
        Rect.fromLTWH(w * s[0], ground - h * s[2], w * s[1], h * s[2]),
        _fill(i.isEven ? _building1 : _building2),
      );
    }
  }

  void _tree(Canvas c, double x, double groundY, double r) {
    _rr(c, x - r * 0.12, groundY - r * 1.6, r * 0.24, r * 1.6, r * 0.1,
        _treeTrunk);
    c.drawCircle(Offset(x, groundY - r * 2.1), r, _fill(_treeLeaf));
    c.drawCircle(Offset(x - r * 0.7, groundY - r * 1.6), r * 0.75,
        _fill(_treeLeaf));
    c.drawCircle(Offset(x + r * 0.7, groundY - r * 1.6), r * 0.75,
        _fill(_treeLeaf));
  }

  void _wheelchairPerson(Canvas c, double x, double ground, double u) {
    final wheelR = 1.6 * u;
    final wheelC = Offset(x, ground - wheelR);
    final seatY = wheelC.dy - 0.1 * u;
    const shirt = Color(0xFF4C6EF5);
    const pants = Color(0xFF1E293B);

    // sandaran + dudukan
    _rr(c, x - 1.7 * u, seatY - 2.6 * u, 0.35 * u, 2.7 * u, 0.15 * u, _chair);
    _rr(c, x - 1.6 * u, seatY, 3.2 * u, 0.45 * u, 0.2 * u, _chair);
    // badan
    _rr(c, x - 1.2 * u, seatY - 2.6 * u, 1.9 * u, 2.7 * u, 0.7 * u, shirt);
    // kepala + rambut
    final headC = Offset(x - 0.25 * u, seatY - 3.4 * u);
    c.drawCircle(headC, 0.75 * u, _fill(_skin));
    c.drawArc(
      Rect.fromCircle(center: headC, radius: 0.8 * u),
      math.pi,
      math.pi,
      true,
      _fill(_hair),
    );
    // paha, betis, sepatu
    _rr(c, x - 0.5 * u, seatY - 0.75 * u, 2.7 * u, 0.85 * u, 0.4 * u, pants);
    _rr(c, x + 1.7 * u, seatY - 0.2 * u, 0.8 * u, 1.9 * u, 0.3 * u, pants);
    _rr(c, x + 1.7 * u, ground - 0.4 * u, 1.3 * u, 0.4 * u, 0.2 * u, _shoe);
    // roda
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.28 * u
      ..color = _chair;
    c.drawCircle(wheelC, wheelR, stroke);
    c.drawCircle(wheelC, 0.25 * u, _fill(_chair));
    c.drawCircle(Offset(x + 2.6 * u, ground - 0.45 * u), 0.45 * u, stroke);
  }

  void _standingPerson(
    Canvas c,
    double x,
    double ground,
    double u, {
    required Color shirt,
    required Color pants,
    bool cane = false,
    bool backpack = false,
  }) {
    final legH = 3.1 * u;
    final torsoTop = ground - legH - 2.7 * u;

    // kaki + sepatu
    _rr(c, x - 0.85 * u, ground - legH, 0.7 * u, legH, 0.25 * u, pants);
    _rr(c, x + 0.15 * u, ground - legH, 0.7 * u, legH, 0.25 * u, pants);
    _rr(c, x - 1.0 * u, ground - 0.35 * u, 1.0 * u, 0.35 * u, 0.15 * u, _shoe);
    _rr(c, x + 0.1 * u, ground - 0.35 * u, 1.0 * u, 0.35 * u, 0.15 * u, _shoe);

    if (backpack) {
      _rr(c, x - 1.5 * u, torsoTop + 0.2 * u, 0.9 * u, 2.0 * u, 0.3 * u,
          const Color(0xFF334155));
    }
    // badan + lengan
    _rr(c, x - 1.0 * u, torsoTop, 2.0 * u, 2.9 * u, 0.6 * u, shirt);
    _rr(c, x - 1.25 * u, torsoTop + 0.3 * u, 0.5 * u, 2.0 * u, 0.25 * u, shirt);
    // kepala + rambut
    final headC = Offset(x, torsoTop - 0.85 * u);
    c.drawCircle(headC, 0.8 * u, _fill(_skin));
    c.drawArc(
      Rect.fromCircle(center: headC, radius: 0.84 * u),
      math.pi,
      math.pi,
      true,
      _fill(_hair),
    );

    if (cane) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.2 * u
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF64748B);
      c.drawLine(
        Offset(x + 1.3 * u, torsoTop + 2.2 * u),
        Offset(x + 2.5 * u, ground),
        p,
      );
    }
  }

  void _dog(Canvas c, double x, double ground, double u) {
    // kaki
    _rr(c, x - 1.1 * u, ground - 1.0 * u, 0.35 * u, 1.0 * u, 0.15 * u, _dogColor);
    _rr(c, x - 0.5 * u, ground - 1.0 * u, 0.35 * u, 1.0 * u, 0.15 * u, _dogColor);
    _rr(c, x + 0.3 * u, ground - 1.0 * u, 0.35 * u, 1.0 * u, 0.15 * u, _dogColor);
    _rr(c, x + 0.8 * u, ground - 1.0 * u, 0.35 * u, 1.0 * u, 0.15 * u, _dogColor);
    // badan, kepala, telinga
    _rr(c, x - 1.3 * u, ground - 2.1 * u, 2.6 * u, 1.2 * u, 0.6 * u, _dogColor);
    c.drawCircle(Offset(x + 1.5 * u, ground - 2.4 * u), 0.6 * u, _fill(_dogColor));
    c.drawOval(
      Rect.fromCenter(
        center: Offset(x + 1.25 * u, ground - 2.45 * u),
        width: 0.35 * u,
        height: 0.7 * u,
      ),
      _fill(const Color(0xFFB98443)),
    );
    // ekor
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3 * u
      ..strokeCap = StrokeCap.round
      ..color = _dogColor;
    c.drawLine(Offset(x - 1.3 * u, ground - 1.8 * u),
        Offset(x - 1.9 * u, ground - 2.5 * u), tail);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.variant != variant;
}
