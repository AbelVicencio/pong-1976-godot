## paddle.gd
## =============================================================================
## Control de Paletas: Jugador (Mouse Scroll / Pantalla Táctil / Teclado) e IA
##
## CONCEPTOS GODOT CLAVE:
## - _input(event): Captura eventos de entrada de más alta prioridad (Mouse, Touch, Teclado).
##   Ideal para entradas que no deben perderse como los ticks de la rueda del ratón
##   o el arrastre táctil continuo (InputEventScreenDrag).
## - InputEventScreenDrag: Reporta el deslizamiento del dedo sobre pantallas táctiles
##   en celulares y tablets, permitiendo control por pulgar sin ratón.
## - lerp(): Interpolación lineal para suavizar el desplazamiento hacia la posición meta,
##   proporcionando respuesta inmediata y libre de vibraciones o saltos bruscos.
## - IA Cinemática: Seguimiento reactivo del eje Y de la bola con zona muerta y límite
##   de velocidad para simular reflejos humanos.
## =============================================================================
extends Node2D

## Si es true, responde a la entrada del usuario; si false, es controlada por la CPU
@export var is_player: bool = true

## Dimensiones de la paleta (ancho, alto)
@export var paddle_size: Vector2 = Vector2(14.0, 76.0)

## Cantidad de píxeles que se desplaza la paleta por cada muesca de la rueda del ratón
@export var scroll_step: float = 40.0

## Velocidad de movimiento al usar teclado (píxeles por segundo)
@export var key_speed: float = 520.0

## Velocidad máxima de la IA (píxeles por segundo)
@export var ai_speed: float = 370.0

# Límites de movimiento vertical de la paleta dentro de la cancha
var min_y: float = 45.0
var max_y: float = 555.0

# Posición objetivo hacia la cual interpola suavemente la paleta
var target_y: float = 300.0

# Referencia a la bola para que la IA pueda rastrear su posición Y
var ball_ref: Node2D = null


func _ready() -> void:
	target_y = position.y
	queue_redraw()


## Ajusta los límites verticales superior e inferior según los muros de la cancha
func set_bounds(top_bound: float, bottom_bound: float) -> void:
	min_y = top_bound + paddle_size.y / 2.0
	max_y = bottom_bound - paddle_size.y / 2.0
	target_y = clamp(position.y, min_y, max_y)
	position.y = target_y


## _input captura eventos crudos de hardware inmediatamente al producirse.
func _input(event: InputEvent) -> void:
	if not is_player:
		return

	# 1. Control principal en PC: rueda del ratón (Mouse Scroll)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_y = clamp(target_y - scroll_step, min_y, max_y)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_y = clamp(target_y + scroll_step, min_y, max_y)

	# 2. Control táctil en celulares y tablets (deslizar con el dedo)
	elif event is InputEventScreenDrag:
		target_y = clamp(event.position.y, min_y, max_y)

	# 3. Toque táctil inicial (tap en la pantalla para posicionar la paleta)
	elif event is InputEventScreenTouch and event.pressed:
		target_y = clamp(event.position.y, min_y, max_y)


## _process se ejecuta en cada fotograma gráfico.
## 'delta' es el tiempo transcurrido en segundos desde el fotograma anterior.
func _process(delta: float) -> void:
	if is_player:
		# Control de respaldo opcional por teclado (W/S o Flechas Arriba/Abajo)
		var key_dir: float = 0.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			key_dir -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			key_dir += 1.0

		if key_dir != 0.0:
			target_y = clamp(target_y + key_dir * key_speed * delta, min_y, max_y)

		# Interpolación suave hacia la posición objetivo (lerp)
		# Un factor de 36.0 * delta garantiza un seguimiento instantáneo y fluido
		position.y = lerp(position.y, target_y, clamp(36.0 * delta, 0.0, 1.0))
	else:
		# Lógica de Inteligencia Artificial (CPU)
		if ball_ref != null and is_instance_valid(ball_ref):
			var ball_pos = ball_ref.position
			var diff = ball_pos.y - position.y

			# Zona muerta de 8px: evita vibración errática cuando la bola está alineada
			if abs(diff) > 8.0:
				var move_amount = sign(diff) * ai_speed * delta
				if abs(move_amount) > abs(diff):
					move_amount = diff
				position.y = clamp(position.y + move_amount, min_y, max_y)

	# Asegurar que la paleta nunca traspase los muros
	position.y = clamp(position.y, min_y, max_y)


## Retorna la caja delimitadora (AABB) de la paleta en coordenadas globales
func get_paddle_rect() -> Rect2:
	return Rect2(position.x - paddle_size.x / 2.0, position.y - paddle_size.y / 2.0, paddle_size.x, paddle_size.y)


## Dibuja la paleta y su halo de luminiscencia catódica (Phosphor Glow)
func _draw() -> void:
	# Capas concéntricas de luminiscencia con decaimiento de opacidad
	var glow_offsets = [5.0, 3.5, 2.0, 1.0]
	var glow_alphas = [0.04, 0.08, 0.15, 0.28]
	for i in range(glow_offsets.size()):
		var exp_pad = glow_offsets[i]
		var col = Color(1.0, 1.0, 1.0, glow_alphas[i])
		draw_rect(
			Rect2(
				-paddle_size.x / 2.0 - exp_pad,
				-paddle_size.y / 2.0 - exp_pad,
				paddle_size.x + exp_pad * 2.0,
				paddle_size.y + exp_pad * 2.0
			),
			col
		)

	# Núcleo blanco sólido central
	draw_rect(Rect2(-paddle_size.x / 2.0, -paddle_size.y / 2.0, paddle_size.x, paddle_size.y), Color.WHITE)
