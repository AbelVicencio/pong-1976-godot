## ball.gd
## =============================================================================
## Lógica de Movimiento, Físicas de Rebote y Estela de la Pelota
##
## CONCEPTOS GODOT CLAVE:
## - Signals: Permiten que este nodo emita eventos ('scored', 'paddle_hit')
##   sin acoplarse directamente a quien los escucha (patrón Observer).
## - _physics_process(delta): Bucle de física con paso de tiempo fijo e
##   independiente del framerate, ideal para cálculos precisos de colisión.
## - _draw(): API CanvasItem de Godot para dibujar primitivas 2D (rectángulos)
##   con aceleración por hardware sin necesidad de sprites o texturas externas.
## =============================================================================
extends Node2D

## Señales emitidas hacia el nodo principal y el gestor de audio
signal scored(winner: String)
signal paddle_hit
signal wall_hit

## Propiedades exportadas visibles y editables en el Inspector de Godot
@export var ball_size: Vector2 = Vector2(14.0, 14.0)
@export var initial_speed: float = 380.0
@export var speed_increment: float = 24.0
@export var max_speed: float = 820.0

# Estado cinemático
var velocity: Vector2 = Vector2.ZERO
var current_speed: float = 380.0
var active: bool = false

# Límites de la cancha calculados en tiempo de ejecución
var top_limit: float = 24.0
var bottom_limit: float = 576.0

## Buffer circular de posiciones previas para la estela de decaimiento de fósforo (CRT ghosting)
var trail_history: Array[Vector2] = []
const MAX_TRAIL_STEPS: int = 5


func _ready() -> void:
	# Solicita a Godot redibujar el nodo mediante _draw()
	queue_redraw()


## Configura los límites verticales de la cancha considerando las dimensiones de la bola
func set_court_bounds(top_bound: float, bottom_bound: float) -> void:
	top_limit = top_bound + ball_size.y / 2.0
	bottom_limit = bottom_bound - ball_size.y / 2.0


## Inicia el saque desde el centro de la cancha
## Parámetros:
##   - direction_right: Si es true, saca hacia la derecha (CPU); si false, hacia el jugador.
func serve(direction_right: bool = true) -> void:
	active = true
	current_speed = initial_speed
	position = Vector2(400.0, 300.0)
	trail_history.clear()

	# Ángulo de lanzamiento inicial aleatorio entre -25° y +25°
	var angle = randf_range(-deg_to_rad(25.0), deg_to_rad(25.0))
	var dir_x = 1.0 if direction_right else -1.0
	velocity = Vector2(cos(angle) * dir_x, sin(angle)) * current_speed
	queue_redraw()


## Detiene por completo el movimiento de la bola y limpia la estela
func stop() -> void:
	active = false
	velocity = Vector2.ZERO
	trail_history.clear()
	queue_redraw()


## _physics_process se ejecuta a una frecuencia fija (por defecto 60 veces por segundo).
## Es el lugar correcto para mover cuerpos y verificar colisiones.
func _physics_process(delta: float) -> void:
	if not active:
		if trail_history.size() > 0:
			trail_history.clear()
			queue_redraw()
		return

	# Almacenar la posición actual en la estela de fósforo
	trail_history.push_front(position)
	if trail_history.size() > MAX_TRAIL_STEPS:
		trail_history.pop_back()

	# Integración de Euler estándar: Posición = Posición + Velocidad * Tiempo
	position += velocity * delta
	queue_redraw()

	# --- Colisión con muros superior e inferior ---
	if position.y <= top_limit:
		position.y = top_limit
		velocity.y = abs(velocity.y) # Asegura rebote hacia abajo
		wall_hit.emit()
	elif position.y >= bottom_limit:
		position.y = bottom_limit
		velocity.y = -abs(velocity.y) # Asegura rebote hacia arriba
		wall_hit.emit()

	# --- Detección de tanto fuera de la pantalla ---
	if position.x < -30.0:
		active = false
		trail_history.clear()
		scored.emit("cpu")
	elif position.x > 830.0:
		active = false
		trail_history.clear()
		scored.emit("player")


## =============================================================================
## Detección y Resolución de Colisión con Paletas (Física Clásica de Pong)
##
## En el Pong original, el ángulo de salida no es un simple espejo del ángulo de entrada.
## Depende directamente de en qué parte de la paleta impacta la bola:
## - Impacto en el centro exacto -> rebote horizontal plano (0°).
## - Impacto en los extremos      -> rebote en ángulo agudo (hasta 55°).
## =============================================================================
func check_paddle_collision(paddle: Node2D) -> void:
	if not active:
		return

	var ball_rect = get_ball_rect()
	var paddle_rect = paddle.get_paddle_rect()

	# Prueba de intersección de cajas alineadas al eje (AABB)
	if ball_rect.intersects(paddle_rect):
		var p_pos = paddle.position
		var p_size = paddle.paddle_size

		# Paleta del Jugador (Izquierda)
		if paddle.is_player and velocity.x < 0:
			# Calcula offset normalizado entre -1.0 (arriba) y +1.0 (abajo)
			var offset = (position.y - p_pos.y) / (p_size.y / 2.0)
			offset = clamp(offset, -1.0, 1.0)
			var angle = offset * deg_to_rad(55.0)

			# Incremento acumulativo de velocidad tras cada raquetazo
			current_speed = min(current_speed + speed_increment, max_speed)
			velocity = Vector2(cos(angle), sin(angle)) * current_speed

			# Reposiciona la bola inmediatamente fuera de la paleta para evitar colisiones múltiples
			position.x = p_pos.x + p_size.x / 2.0 + ball_size.x / 2.0 + 1.0
			paddle_hit.emit()

		# Paleta de la CPU (Derecha)
		elif (not paddle.is_player) and velocity.x > 0:
			var offset = (position.y - p_pos.y) / (p_size.y / 2.0)
			offset = clamp(offset, -1.0, 1.0)
			var angle = offset * deg_to_rad(55.0)

			current_speed = min(current_speed + speed_increment, max_speed)
			# Velocidad en X negativa para regresar hacia la izquierda
			velocity = Vector2(-cos(angle), sin(angle)) * current_speed

			position.x = p_pos.x - p_size.x / 2.0 - ball_size.x / 2.0 - 1.0
			paddle_hit.emit()


## Retorna la caja delimitadora (AABB) de la bola en coordenadas globales
func get_ball_rect() -> Rect2:
	return Rect2(position.x - ball_size.x / 2.0, position.y - ball_size.y / 2.0, ball_size.x, ball_size.y)


## Función de renderizado gráfico CanvasItem de Godot
func _draw() -> void:
	# 1. Halo exterior suave de fósforo (aura del haz catódico)
	var glow_border = 2.0
	draw_rect(
		Rect2(
			-ball_size.x / 2.0 - glow_border,
			-ball_size.y / 2.0 - glow_border,
			ball_size.x + glow_border * 2.0,
			ball_size.y + glow_border * 2.0
		),
		Color(1.0, 1.0, 1.0, 0.14)
	)

	# 2. Estela de decaimiento de persistencia de fósforo
	var trail_count = trail_history.size()
	for i in range(trail_count - 1, -1, -1):
		# Coordenada relativa al centro actual de la bola
		var rel_pos = trail_history[i] - position
		var progress = 1.0 - (float(i) / float(trail_count))
		var alpha = progress * 0.18 # Atenuado para evitar saturar el brillo
		var trail_color = Color(1.0, 1.0, 1.0, alpha)
		draw_rect(Rect2(rel_pos.x - ball_size.x / 2.0, rel_pos.y - ball_size.y / 2.0, ball_size.x, ball_size.y), trail_color)

	# 3. Núcleo sólido blanco de la bola
	draw_rect(Rect2(-ball_size.x / 2.0, -ball_size.y / 2.0, ball_size.x, ball_size.y), Color.WHITE)
