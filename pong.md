# 📚 Manual de Arquitectura y Aprendizaje de Godot 4: PONG
> **Guía Técnica para Desarrolladores de Software que Aprenden Godot Engine.**  
> Basado en la implementación de *Pong Clásico (Atari Clone) con Shader CRT y Audio Procedural*.

---

## 📑 Tabla de Contenidos

1. [Filosofía Fundamental de Godot 4](#1-filosofía-fundamental-de-godot-4)
2. [Jerarquía de Nodos y Estructura del Proyecto](#2-jerarquía-de-nodos-y-estructura-del-proyecto)
3. [El Ciclo de Vida del Motor (Lifecycle)](#3-el-ciclo-de-vida-del-motor-lifecycle)
4. [Arquitectura de Manejo de Entradas (Input Flow)](#4-arquitectura-de-manejo-de-entradas-input-flow)
5. [Renderizado Vectorial en GPU con la API `_draw()`](#5-renderizado-vectorial-en-gpu-con-la-api-_draw)
6. [Patrón Observer y Señales (Signals)](#6-patrón-observer-y-señales-signals)
7. [Animaciones Programáticas con Tweens](#7-animaciones-programáticas-con-tweens)
8. [Síntesis Procedural de Audio 8-Bits en Memoria](#8-síntesis-procedural-de-audio-8-bits-en-memoria)
9. [Shaders en Godot 4: Emulación Catódica (CRT)](#9-shaders-en-godot-4-emulación-catódica-crt)
10. [Física de Rebote Clásica e Inteligencia Artificial](#10-física-de-rebote-clásica-e-inteligencia-artificial)
11. [Guía de Buenas Prácticas en GDScript 2.0](#11-guía-de-buenas-prácticas-en-gdscript-20)

---

## 1. Filosofía Fundamental de Godot 4

Si vienes de motores basados en componentes (como Unity) o de frameworks orientados a objetos tradicionales (como Qt, JavaFX o React):

- **Todo es un Nodo (`Node`)**: La unidad elemental de construcción en Godot es el `Node`.
- **Todo es una Escena (`Scene / .tscn`)**: En Godot no hay diferencia rígida entre un "Prefabs", una "Pantalla" o un "Nivel". Una escena es simplemente un árbol de nodos empaquetado y reutilizable.
- **Composición sobre Herencia**: Construyes objetos complejos anidando nodos especializados.
- **Relación Árbol (`SceneTree`)**: Cada fotograma, Godot recorre el árbol de nodos de arriba hacia abajo (o en orden inverso según la etapa).

---

## 2. Jerarquía de Nodos y Estructura del Proyecto

En este proyecto, la escena principal [`main.tscn`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/main.tscn) se compone del siguiente árbol:

```text
Main (Node2D)                     <-- Script controlador: main.gd
├── Court (Node2D)                <-- Dibuja muros y red: court.gd
├── PlayerScoreDisplay (Node2D)   <-- Marcador 7-segmentos izq: digit_display.gd
├── CPUScoreDisplay (Node2D)      <-- Marcador 7-segmentos der: digit_display.gd
├── PlayerPaddle (Node2D)         <-- Paleta jugador: paddle.gd (is_player = true)
├── CPUPaddle (Node2D)            <-- Paleta CPU: paddle.gd (is_player = false)
├── Ball (Node2D)                 <-- Bola física y estela: ball.gd
├── AudioManager (Node)           <-- Síntesis de sonido WAV: audio_manager.gd
├── UI (Control)                  <-- Textos informativos de juego
│   ├── MessageLabel (Label)
│   ├── SubLabel (Label)
│   ├── ControlsLabel (Label)
│   └── NotificationLabel (Label)
├── CRTLayer (CanvasLayer = 10)   <-- Post-procesamiento CRT
│   └── CRT (ColorRect con ShaderMaterial: crt_material.gdshader)
└── CoverLayer (CanvasLayer = 20) <-- Portada física exterior (sin shader)
    └── CoverScreen (Control)
        ├── CoverTexture (TextureRect con portada.jpg)
        └── CoverPrompt (Label pulsante)
```

### 🧠 ¿Por qué usamos dos `CanvasLayer` separados?
1. **`CanvasLayer` (layer = 10)**: Renderiza el filtro CRT sobre todo lo que esté en capas inferiores (0 a 9). Captura la cancha, paletas, bola y marcador a través de `hint_screen_texture`.
2. **`CanvasLayer` (layer = 20)**: Está **por encima** del CRT. Esto permite que el cartel exterior ([`portada.jpg`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/portada.jpg)) se muestre en alta resolución impecable, simulando la marquesina exterior del mueble arcade antes de entrar al tubo de vidrio.

---

## 3. El Ciclo de Vida del Motor (Lifecycle)

Cada script que hereda de `Node` o `Node2D` participa en el ciclo de vida del motor:

```
[ Instanciación ]
       │
   _init()            <-- Se llama al crear el objeto en memoria (new()).
       │
  _enter_tree()       <-- El nodo entra en el árbol activo de Godot.
       │
   _ready()           <-- Todos los hijos del nodo ya entraron y están listos.
       │
 [ Bucle de Juego ] ──► _physics_process(delta)  (Paso fijo, ej: 60 Hz)
       │            ──► _process(delta)          (Paso variable, fotogramas por segundo)
       │            ──► _input(event)            (Entradas de hardware)
       │            ──► _unhandled_input(event)  (Entradas no consumidas por UI)
       │
  _exit_tree()        <-- El nodo es retirado del árbol.
```

### `_process(delta)` frente a `_physics_process(delta)`
- **`_process(delta)`**: Corre tan rápido como tu GPU/monitor lo permita (60, 144, 240 FPS). Se usa en [`paddle.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/paddle.gd) para realizar la interpolación suave (`lerp`) de la paleta.
- **`_physics_process(delta)`**: Corre a una cadencia matemática fija (predeterminada a 60 ticks por segundo). Se usa en [`ball.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/ball.gd) para que las colisiones e incrementos de velocidad sean deterministas y no dependan de los FPS del monitor.

---

## 4. Arquitectura de Manejo de Entradas (Input Flow)

Godot procesa los eventos de entrada en un orden estricto:

```
Evento de Hardware (Teclado / Ratón)
          │
          ▼
   1. _input(event)           <-- Máxima prioridad (main.gd y paddle.gd)
          │
          ▼
   2. Nodos Control (GUI)     <-- Si hacen clic sobre un botón y lo consume
          │
          ▼
   3. _unhandled_input(event) <-- Entrada libre no consumida por la interfaz
```

### Reglas Clave Implementadas en el Proyecto

1. **La rueda del ratón (`Mouse Scroll`)**:  
   En Godot, la rueda es considerada un botón dentro de `InputEventMouseButton`:
   - `MOUSE_BUTTON_WHEEL_UP`
   - `MOUSE_BUTTON_WHEEL_DOWN`
2. **Consumo de eventos**:  
   Cuando un evento no debe propagarse más allá, se utiliza:
   ```gdscript
   get_viewport().set_input_as_handled()
   ```
3. **El filtro de la portada**:  
   En [`main.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/main.gd), se descartan explícitamente los eventos `MOUSE_BUTTON_WHEEL_*` mientras `current_state == State.COVER`, asegurando que el scroll solo controle la paleta y no salte accidentalmente la portada.

---

## 5. Renderizado Vectorial en GPU con la API `_draw()`

En lugar de cargar archivos PNG con texturas de rectángulos blancos para los muros, la red y la bola, los nodos usan la función virtual `_draw()`.

### Ventajas para un Programador:
- Cero dependencias de archivos de imagen auxiliares.
- Consumo mínimo de VRAM.
- Escalado perfecto sin pixelación borrosa.

### Ejemplo en [`digit_display.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/digit_display.gd):
```gdscript
func _draw() -> void:
    for seg_idx in active_segments:
        draw_rect(rects[seg_idx], color)
```
> **Nota de rendimiento**: `_draw()` no se ejecuta cada fotograma por defecto. Solo se vuelve a invocar cuando llamas explícitamente a `queue_redraw()`.

---

## 6. Patrón Observer y Señales (Signals)

La regla de oro de la arquitectura en Godot es:  
**"Call Down, Signal Up"** (Llama hacia abajo con métodos, notifica hacia arriba con señales).

### Implementación en [`ball.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/ball.gd):
```gdscript
# Declaración de la señal en el hijo:
signal scored(winner: String)

# Emisión en el momento del evento:
scored.emit("player")
```

### Conexión en [`main.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/main.gd):
```gdscript
# El padre conecta la señal a su propia función receptora:
ball.scored.connect(_on_ball_scored)

func _on_ball_scored(scorer: String) -> void:
    if scorer == "player":
        player_score += 1
```
Esto mantiene a la pelota totalmente desacoplada de la interfaz, el sistema de audio o las reglas de puntaje.

---

## 7. Animaciones Programáticas con Tweens

Los `Tween` en Godot 4 son utilidades livianas para interpolar valores en el tiempo sin necesidad de crear archivos de animación `.anim`.

### Ejemplo: Pulso infinito de texto en la portada
```gdscript
var pulse = create_tween().set_loops()
pulse.tween_property(cover_prompt, "modulate:a", 0.30, 0.55)
pulse.tween_property(cover_prompt, "modulate:a", 1.0, 0.55)
```

### Ejemplo: Transición suave de salida (*Fade-out*) y callback
```gdscript
var fade = create_tween()
fade.tween_property(cover_screen, "modulate:a", 0.0, 0.30)
fade.tween_callback(func():
    cover_screen.visible = false
)
```

---

## 8. Síntesis Procedural de Audio 8-Bits en Memoria

En [`audio_manager.gd`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/audio_manager.gd), generamos la señal de audio directamente construyendo un `PackedByteArray`:

```gdscript
var stream = AudioStreamWAV.new()
stream.format = AudioStreamWAV.FORMAT_8_BITS # 1 byte por muestra (0-255)
stream.mix_rate = 22050                     # 22.050 muestras por segundo
stream.stereo = false                       # Canal mono
```

### Ecuación de la Onda Cuadrada:
$$\text{fase} = (t \cdot f) \pmod{1}$$
$$\text{muestra} = \begin{cases} +1.0 & \text{si fase } < 0.5 \\ -1.0 & \text{si fase } \ge 0.5 \end{cases}$$

Para evitar el molesto chasquido (*audio click*) al terminar el sonido, aplicamos una rampa de decaimiento lineal en los últimos 10 milisegundos (`fade_samples`).

---

## 9. Shaders en Godot 4: Emulación Catódica (CRT)

El archivo [`crt_material.gdshader`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/crt_material.gdshader) es un shader GLSL de tipo `canvas_item`.

### 1. Lectura del Búfer de Pantalla
```shader
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
```
Permite leer los píxeles previamente calculados por la GPU en las capas inferiores.

### 2. Deformación Esférica del Tubo (*Barrel Warp*)
```shader
vec2 warp(vec2 uv) {
    vec2 dc = uv - 0.5;
    float d = dot(dc, dc);
    return 0.5 + dc * (1.0 + warp_amount * d * 4.0);
}
```
Desplaza las coordenadas UV hacia el exterior cuadráticamente con respecto a la distancia al centro $(0.5, 0.5)$.

### 3. Scanlines Matemáticas
```shader
float scanline = sin(uv.y * scanline_count * 3.14159265);
scanline = (scanline + 1.0) * 0.5;
col *= 1.0 - (scanline * scanline_intensity);
```
Genera bandas horizontales de oscurecimiento periódicas basadas en una función seno.

### 4. Halación / Phosphor Bloom
Muestreamos 8 puntos adyacentes en forma de estrella (`uv ± offset`) para simular la dispersión de luz en el recubrimiento de fósforo del cristal del televisor.

---

## 10. Física de Rebote Clásica e Inteligencia Artificial

### Cálculo del Ángulo de Retorno (Atari Pong Clásico)
A diferencia de un rebote elástico convencional donde $\theta_{\text{salida}} = \theta_{\text{entrada}}$, en Pong el ángulo depende de la posición relativa de impacto en la paleta:

```gdscript
# offset ∈ [-1.0 (extremo superior), +1.0 (extremo inferior)]
var offset = (ball.position.y - paddle.position.y) / (paddle_height / 2.0)
offset = clamp(offset, -1.0, 1.0)

# Ángulo máximo de 55 grados
var bounce_angle = offset * deg_to_rad(55.0)

# El vector velocidad se recalcula a partir del ángulo:
velocity = Vector2(cos(bounce_angle) * dir_x, sin(bounce_angle)) * current_speed
```

### Inteligencia Artificial Reactiva
La paleta derecha no hace trampa: rastrea el valor `position.y` de la bola con una zona muerta de $8\text{ px}$ y una velocidad máxima finita (`ai_speed = 370.0`), lo que permite ganarle si devuelves la bola con ángulos pronunciados a alta velocidad.

---

## 11. Guía de Buenas Prácticas en GDScript 2.0

1. **Tipado Estático Estricto**:  
   Usa siempre anotaciones de tipo (`var speed: float = 300.0`, `func serve() -> void:`). Permite al compilador optimizar el bytecode e informarte de errores antes de ejecutar.
2. **Uso de `@onready`**:  
   Resuelve rutas de nodos hijas cuando el nodo ya fue agregado al árbol, previniendo errores de puntero nulo (`NullReference`).
3. **Control de Escala (`CanvasItem Stretch Mode`)**:  
   En [`project.godot`](file:///C:/Users/abelv/OneDrive/Code/pruebas/pong/project.godot) se configuró:
   ```ini
   window/stretch/mode="canvas_items"
   window/stretch/aspect="keep"
   ```
   Esto asegura que el juego conserve su resolución base de $800 \times 600$ y su relación 4:3 en cualquier tamaño de monitor sin romper la escala.

---

## 🚀 Comandos Rápidos de Ejecución y Pruebas

```powershell
# Ejecución en consola de depuración:
Godot_console.exe

# Ejecución limpia directa:
Godot.exe

# Reimportación sin interfaz:
Godot_console.exe --headless --import
```
