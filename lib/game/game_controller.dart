import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Controla el estado del juego y la física.
///
/// - Recibe eventos del acelerómetro (tilt) y los transforma en aceleración.
/// - Actualiza posiciones/velocidades en un bucle de juego (tick).
/// - Notifica a la UI con [notifyListeners] cuando hay cambios.
class GameController extends ChangeNotifier {
  GameController({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  StreamSubscription<AccelerometerEvent>? _sub;
  Offset _tilt = Offset.zero;

  bool invertX = false;
  bool invertY = false;

  /// Sensibilidad fija del movimiento.
  static const double sensitivity = 45;

  /// Tamaño del jugador en pixeles.
  double playerRadius = 18;

  /// Tamaño del objetivo en pixeles.
  double targetRadius = 16;

  /// Cantidad de obstáculos por ronda.
  int obstaclesPerRound = 6;

  /// Velocidad máxima del jugador en px/s.
  double maxSpeed = 900;

  /// Fricción (0..1). Más cerca de 1 = se desliza más.
  double frictionPer60Fps = 0.90;

  int score = 0;

  void setInvertX(bool value) {
    invertX = value;
    notifyListeners();
  }

  void setInvertY(bool value) {
    invertY = value;
    notifyListeners();
  }

  /// Área jugable (en pixeles). Se define cuando la UI tiene tamaño.
  Size _bounds = Size.zero;
  bool _initialized = false;

  Offset playerPos = Offset.zero;
  Offset playerVel = Offset.zero;

  Offset targetPos = Offset.zero;
  final List<Rect> obstacles = <Rect>[];

  bool get isInitialized => _initialized;
  Size get bounds => _bounds;

  void attachSensors() {
    _sub ??= accelerometerEventStream().listen((event) {
      // Mapeo sencillo para portrait: inclinación → vector de movimiento.
      // Si el control se siente “al revés”, usa invertX/invertY.
      var x = -event.x;
      var y = event.y;
      if (invertX) x = -x;
      if (invertY) y = -y;
      _tilt = Offset(x, y);
    });
  }

  void detachSensors() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    detachSensors();
    super.dispose();
  }

  /// Llamar cuando el canvas conoce su tamaño.
  void ensureInitialized(Size bounds) {
    if (bounds.isEmpty) return;
    if (_initialized && bounds == _bounds) return;
    _bounds = bounds;
    if (!_initialized) {
      _initialized = true;
      _resetPositions();
      _startNewRound();
      notifyListeners();
    } else {
      // Si cambió el tamaño (rotación), re-ajusta posiciones dentro del área.
      playerPos = _clampToBounds(playerPos, playerRadius);
      targetPos = _clampToBounds(targetPos, targetRadius);
      _clampObstaclesToBounds();
      notifyListeners();
    }
  }

  void reset() {
    if (!_initialized) return;
    score = 0;
    _resetPositions();
    _startNewRound();
    notifyListeners();
  }

  void _resetPositions() {
    final center = Offset(_bounds.width / 2, _bounds.height / 2);
    playerPos = center;
    playerVel = Offset.zero;
  }

  void _startNewRound() {
    _spawnTarget();
    _spawnObstacles();
  }

  void _spawnTarget() {
    if (_bounds.isEmpty) return;

    final padding = math.max(targetRadius, 24.0);
    var candidate = targetPos;
    for (var i = 0; i < 20; i++) {
      candidate = Offset(
        _randomRange(padding, _bounds.width - padding),
        _randomRange(padding, _bounds.height - padding),
      );
      if ((candidate - playerPos).distance > 120) {
        break;
      }
    }
    targetPos = candidate;
  }

  double _randomRange(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  void _spawnObstacles() {
    obstacles.clear();
    if (_bounds.isEmpty || obstaclesPerRound <= 0) return;

    // Tamaño aproximado de obstáculos (rectángulos).
    const minW = 70.0;
    const maxW = 160.0;
    const minH = 26.0;
    const maxH = 70.0;
    const padding = 14.0;

    final playArea = Rect.fromLTWH(
      padding,
      padding,
      _bounds.width - padding * 2,
      _bounds.height - padding * 2,
    );

    var created = 0;
    var attempts = 0;
    while (created < obstaclesPerRound && attempts < obstaclesPerRound * 40) {
      attempts += 1;

      final w = _randomRange(minW, maxW);
      final h = _randomRange(minH, maxH);
      final left = _randomRange(playArea.left, playArea.right - w);
      final top = _randomRange(playArea.top, playArea.bottom - h);
      final rect = Rect.fromLTWH(left, top, w, h);

      // No bloquear el inicio del jugador ni el objetivo.
      if (_circleIntersectsRect(playerPos, playerRadius + 14, rect)) continue;
      if (_circleIntersectsRect(targetPos, targetRadius + 18, rect)) continue;

      // Evitar superposición entre obstáculos.
      var overlaps = false;
      for (final other in obstacles) {
        if (rect.overlaps(other.inflate(8))) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;

      obstacles.add(rect);
      created += 1;
    }
  }

  /// Avanza el juego.
  ///
  /// [dtSeconds] debe ser el delta de tiempo en segundos (ej: 1/60).
  void update(double dtSeconds) {
    if (!_initialized) return;
    if (dtSeconds <= 0) return;

    // Aceleración (px/s^2) derivada del acelerómetro.
    final accel = _tilt * sensitivity * 18;

    playerVel += accel * dtSeconds;
    playerVel = _clampSpeed(playerVel, maxSpeed);

    // Fricción independiente de FPS (aproximación).
    final friction =
        math.pow(frictionPer60Fps, dtSeconds * 60).toDouble().clamp(0.0, 1.0);
    playerVel = playerVel * friction;

    playerPos += playerVel * dtSeconds;
    _resolveBoundsForPlayer();
    _resolveObstacleCollisions();

    if ((playerPos - targetPos).distance <= (playerRadius + targetRadius)) {
      score += 1;
      _startNewRound();
      // Empujón suave para que se sienta “nuevo round”.
      playerVel *= 0.6;
    }

    notifyListeners();
  }

  void _resolveBoundsForPlayer() {
    final left = playerRadius;
    final top = playerRadius;
    final right = _bounds.width - playerRadius;
    final bottom = _bounds.height - playerRadius;

    var px = playerPos.dx;
    var py = playerPos.dy;
    var vx = playerVel.dx;
    var vy = playerVel.dy;

    const bounce = 0.55;
    if (px < left) {
      px = left;
      vx = -vx * bounce;
    } else if (px > right) {
      px = right;
      vx = -vx * bounce;
    }
    if (py < top) {
      py = top;
      vy = -vy * bounce;
    } else if (py > bottom) {
      py = bottom;
      vy = -vy * bounce;
    }

    playerPos = Offset(px, py);
    playerVel = Offset(vx, vy);
  }

  void _resolveObstacleCollisions() {
    if (obstacles.isEmpty) return;

    for (final rect in obstacles) {
      final closest = Offset(
        playerPos.dx.clamp(rect.left, rect.right).toDouble(),
        playerPos.dy.clamp(rect.top, rect.bottom).toDouble(),
      );
      var delta = playerPos - closest;
      var dist = delta.distance;

      if (dist >= playerRadius) continue;

      // Caso raro: el centro cayó exactamente en el punto más cercano.
      if (dist == 0) {
        final leftPen = (playerPos.dx - rect.left).abs();
        final rightPen = (rect.right - playerPos.dx).abs();
        final topPen = (playerPos.dy - rect.top).abs();
        final bottomPen = (rect.bottom - playerPos.dy).abs();

        final minPen = math.min(math.min(leftPen, rightPen), math.min(topPen, bottomPen));
        if (minPen == leftPen) {
          delta = const Offset(-1, 0);
        } else if (minPen == rightPen) {
          delta = const Offset(1, 0);
        } else if (minPen == topPen) {
          delta = const Offset(0, -1);
        } else {
          delta = const Offset(0, 1);
        }
        dist = 1;
      }

      final normal = delta / dist;
      final penetration = playerRadius - dist;

      // Empuja al jugador fuera del obstáculo.
      playerPos += normal * penetration;

      // Quita la componente de velocidad que va hacia el obstáculo.
      final vn = playerVel.dx * normal.dx + playerVel.dy * normal.dy;
      if (vn < 0) {
        playerVel -= normal * vn;
      }
    }

    // Re-aplica límites por si el empuje lo sacó del área.
    _resolveBoundsForPlayer();
  }

  bool _circleIntersectsRect(Offset center, double radius, Rect rect) {
    final closest = Offset(
      center.dx.clamp(rect.left, rect.right).toDouble(),
      center.dy.clamp(rect.top, rect.bottom).toDouble(),
    );
    return (center - closest).distance <= radius;
  }

  void _clampObstaclesToBounds() {
    if (obstacles.isEmpty) return;
    final clamped = <Rect>[];
    for (final rect in obstacles) {
      final left = rect.left.clamp(0.0, _bounds.width - rect.width).toDouble();
      final top = rect.top.clamp(0.0, _bounds.height - rect.height).toDouble();
      clamped.add(Rect.fromLTWH(left, top, rect.width, rect.height));
    }
    obstacles
      ..clear()
      ..addAll(clamped);
  }

  Offset _clampSpeed(Offset v, double max) {
    final len = v.distance;
    if (len <= max || len == 0) return v;
    return v * (max / len);
  }

  Offset _clampToBounds(Offset pos, double radius) {
    final x = pos.dx.clamp(radius, _bounds.width - radius).toDouble();
    final y = pos.dy.clamp(radius, _bounds.height - radius).toDouble();
    return Offset(x, y);
  }
}
