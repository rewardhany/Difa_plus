import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Joystick virtual analog untuk menggerakkan titik simulasi mahasiswa di denah.
///
/// Mendukung drag sentuh (mobile) maupun mouse (web/desktop), serta memanggil
/// [onActiveChanged] agar ListView induk tidak ikut ter-scroll saat joystick digeser.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.onMove,
    this.onActiveChanged,
    this.size = 116,
    this.knobSize = 44,
    this.accentColor,
  });

  /// Dipanggil berkala (~30 FPS) saat joystick digerakkan dengan vektor ternormalisasi
  /// `dx`, `dy` dalam rentang `-1.0 .. 1.0`.
  final void Function(double dx, double dy) onMove;

  /// Dipanggil saat pengguna mulai/berhenti menyentuh joystick.
  final ValueChanged<bool>? onActiveChanged;

  final double size;
  final double knobSize;
  final Color? accentColor;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knobOffset = Offset.zero;
  bool _active = false;
  Timer? _tickTimer;

  double get _maxRadius => (widget.size - widget.knobSize) / 2;

  void _startTracking(Offset localPosition) {
    _updateOffset(localPosition);
    if (!_active) {
      setState(() => _active = true);
      widget.onActiveChanged?.call(true);
    }
    _tickTimer ??= Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _emitCurrentVector(),
    );
    _emitCurrentVector();
  }

  void _updateOffset(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    var delta = localPosition - center;
    final dist = delta.distance;
    if (dist > _maxRadius && dist > 0) {
      delta = delta * (_maxRadius / dist);
    }
    setState(() => _knobOffset = delta);
  }

  void _emitCurrentVector() {
    if (_maxRadius <= 0) return;
    final dx = (_knobOffset.dx / _maxRadius).clamp(-1.0, 1.0);
    final dy = (_knobOffset.dy / _maxRadius).clamp(-1.0, 1.0);
    if (dx.abs() < 0.08 && dy.abs() < 0.08) return;
    widget.onMove(dx, dy);
  }

  void _stopTracking() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (_active || _knobOffset != Offset.zero) {
      setState(() {
        _active = false;
        _knobOffset = Offset.zero;
      });
      widget.onActiveChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final radius = widget.size / 2;

    return Semantics(
      label: 'Joystick simulasi gerak mahasiswa. Geser untuk memindahkan posisi di peta.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _startTracking(e.localPosition),
        onPointerMove: (e) => _updateOffset(e.localPosition),
        onPointerUp: (_) => _stopTracking(),
        onPointerCancel: (_) => _stopTracking(),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Lingkaran dasar joystick
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: _active ? 0.14 : 0.08),
                  border: Border.all(
                    color: primary.withValues(alpha: _active ? 0.55 : 0.28),
                    width: 2,
                  ),
                ),
              ),
              // Lingkaran panduan dalam
              Container(
                width: widget.size * 0.52,
                height: widget.size * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
              ),
              // Indikator panah arah (Utara, Selatan, Barat, Timur)
              Positioned(
                top: 6,
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 16,
                  color: primary.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                bottom: 6,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: primary.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                left: 6,
                child: Icon(
                  Icons.keyboard_arrow_left,
                  size: 16,
                  color: primary.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                right: 6,
                child: Icon(
                  Icons.keyboard_arrow_right,
                  size: 16,
                  color: primary.withValues(alpha: 0.55),
                ),
              ),
              // Knob / tuas yang digeser
              Transform.translate(
                offset: _knobOffset,
                child: AnimatedContainer(
                  duration: _active
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  width: widget.knobSize,
                  height: widget.knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: _active ? 0.45 : 0.25),
                        blurRadius: _active ? 12 : 6,
                        offset: Offset(
                          0,
                          math.max(1, radius * 0.04),
                        ),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_with,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
