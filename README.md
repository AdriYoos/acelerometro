# acelerometro

Mini‑juego en Flutter controlado con el acelerómetro (`sensors_plus`).

## ¿Qué hace?

- Mueves al jugador (círculo azul) inclinando el celular.
- Debes alcanzar el objetivo (círculo verde) para sumar puntos.
- Cada vez que alcanzas el objetivo:
  - sube el **Score**
  - el objetivo cambia de lugar
  - se generan obstáculos nuevos (rectángulos)

## Controles

- **Invertir X / Invertir Y**: invierte el sentido del movimiento por si el tilt se siente “al revés”.
- **Coordenadas del jugador (X, Y)**: muestra la posición del jugador en pixeles dentro del área de juego.

## Capturas de pantalla (qué poner y por qué)

Guarda tus imágenes en `assets/screenshots/` con estos nombres (recomendado):

1. `assets/screenshots/01_inicio.png`
   - Representa: vista general del juego (jugador, objetivo, obstáculos y el Score).
2. `assets/screenshots/02_coordenadas.png`
   - Representa: el panel mostrando **Coordenadas del jugador: X=… Y=…**.
3. `assets/screenshots/03_invertir_xy.png`
   - Representa: switches de **Invertir X/Y** activados (útil si el movimiento iba al revés).
4. `assets/screenshots/04_score.png`
   - Representa: un Score > 0 después de alcanzar el objetivo (demuestra que la lógica de rondas funciona).

Luego, cuando existan esos archivos, se verán aquí:

| Inicio | Coordenadas |
| --- | --- |
| ![Inicio](assets/screenshots/01_inicio.png) | ![Coordenadas](assets/screenshots/02_coordenadas.png) |

| Invertir X/Y | Score |
| --- | --- |
| ![Invertir](assets/screenshots/03_invertir_xy.png) | ![Score](assets/screenshots/04_score.png) |

## Cómo ejecutar

```bash
flutter pub get
flutter run
```

## Estructura del código

- `lib/main.dart`: entrypoint de Flutter.
- `lib/screens/game_screen.dart`: pantalla del juego (UI + loop con `Ticker`).
- `lib/game/game_controller.dart`: estado + física (colisiones, score, suscripción al acelerómetro).
- `lib/game/game_painter.dart`: render del juego con `CustomPainter`.
