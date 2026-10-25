## digit_display.gd
## =============================================================================
## Marcador Digital Retro Estilo 7 Segmentos (Atari Pong 1976)
##
## CONCEPTOS GODOT:
## - Propiedades con 'set(new_val)': Permite reaccionar a cambios de valor
##   invocando queue_redraw() automáticamente para refrescar la pantalla.
## - Renderizado de Glifos Procedural: En lugar de cargar una fuente TTF externa,
##   los dígitos del 0 al 9 se componen mediante 7 segmentos rectangulares (A a G)
##   con idéntica geometría a los tableros digitales de los años 70.
## =============================================================================
extends Node2D

## Valor numérico que se mostrará en el marcador
@export var value: int = 0:
	set(new_val):
		value = new_val
		queue_redraw() # Solicita a Godot redibujar cuando cambie el puntaje

# Dimensiones geométricas de cada dígito
@export var digit_width: float = 38.0
@export var digit_height: float = 64.0
@export var thickness: float = 8.0
@export var spacing: float = 14.0
@export var color: Color = Color.WHITE

## Mapeo estándar de 7 segmentos para los dígitos 0 al 9:
##
##       --- 0 (A) ---
##      |             |
##    5 (F)         1 (B)
##      |             |
##       --- 6 (G) ---
##      |             |
##    4 (E)         2 (C)
##      |             |
##       --- 3 (D) ---
##
const SEGMENTS = {
	0: [0, 1, 2, 3, 4, 5],
	1: [1, 2],
	2: [0, 1, 6, 4, 3],
	3: [0, 1, 6, 2, 3],
	4: [5, 6, 1, 2],
	5: [0, 5, 6, 2, 3],
	6: [0, 5, 4, 3, 2, 6],
	7: [0, 1, 2],
	8: [0, 1, 2, 3, 4, 5, 6],
	9: [0, 1, 2, 3, 5, 6]
}


## Dibuja todos los dígitos del número actual centrados horizontalmente
func _draw() -> void:
	var val_str = str(value)
	var total_w = val_str.length() * digit_width + (val_str.length() - 1) * spacing
	var start_x = -total_w / 2.0

	for i in range(val_str.length()):
		var digit = int(val_str[i])
		var dx = start_x + i * (digit_width + spacing)
		_draw_digit(Vector2(dx, -digit_height / 2.0), digit)


## Dibuja un único dígito en una posición dada activando sus segmentos correspondientes
func _draw_digit(pos: Vector2, d: int) -> void:
	if not SEGMENTS.has(d):
		return
	var active_segments = SEGMENTS[d]
	var w = digit_width
	var h = digit_height
	var t = thickness
	var half_h = h / 2.0

	# Definición geométrica de los 7 rectángulos de segmento
	# 0: Superior, 1: Sup-Der, 2: Inf-Der, 3: Inferior, 4: Inf-Izq, 5: Sup-Izq, 6: Central
	var rects = [
		Rect2(pos.x, pos.y, w, t),                              # 0: A
		Rect2(pos.x + w - t, pos.y, t, half_h),                 # 1: B
		Rect2(pos.x + w - t, pos.y + half_h, t, half_h),        # 2: C
		Rect2(pos.x, pos.y + h - t, w, t),                      # 3: D
		Rect2(pos.x, pos.y + half_h, t, half_h),                # 4: E
		Rect2(pos.x, pos.y, t, half_h),                         # 5: F
		Rect2(pos.x, pos.y + half_h - t / 2.0, w, t)            # 6: G
	]

	for seg_idx in active_segments:
		draw_rect(rects[seg_idx], color)
