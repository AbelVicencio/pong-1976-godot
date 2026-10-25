## main.gd
## =============================================================================
## Controlador Principal de Pong Clásico (Máquina de Estados y Flujo de Juego)
##
## CONCEPTOS GODOT CLAVE:
## - Máquina de Estados Finitos (FSM): Estructura el ciclo de vida del juego
##   (COVER -> IDLE -> PLAYING -> POINT_SCORED -> GAME_OVER).
## - Jerarquía de Entrada (_input vs _unhandled_input):
##   * _input(): Intercepta teclas globales como ESC o clics para salir de la portada.
##   * _unhandled_input(): Atiende eventos de juego que no fueron consumidos por la UI.
## - Tweens de Godot: Creación de animaciones programáticas fluidas (fade-in, fade-out,
##   pulsos de texto) sin necesidad de AnimationPlayer.
## =============================================================================
extends Node2D

## Estados posibles del juego
enum State {
	COVER,        # Mostrando el cartel exterior del gabinete (portada.jpg)
	IDLE,         # En la cancha esperando saque (clic o scroll)
	PLAYING,      # Pelota en juego activo
	POINT_SCORED, # Pausa tras anotar un tanto
	GAME_OVER     # Fin de partida al llegar a 11 puntos
}

var current_state: State = State.COVER
var player_score: int = 0
var cpu_score: int = 0
const WINNING_SCORE: int = 11

## Referencias @onready a los nodos de la escena (se resuelven al entrar al árbol)
@onready var court = $Court
@onready var player_paddle = $PlayerPaddle
@onready var cpu_paddle = $CPUPaddle
@onready var ball = $Ball
@onready var audio_manager = $AudioManager
@onready var player_score_display = $PlayerScoreDisplay
@onready var cpu_score_display = $CPUScoreDisplay
@onready var message_label = get_node_or_null("UI/MessageLabel")
@onready var sub_label = get_node_or_null("UI/SubLabel")
@onready var controls_label = get_node_or_null("UI/ControlsLabel")
@onready var crt_rect = get_node_or_null("CRTLayer/CRT")
@onready var notification_label = get_node_or_null("UI/NotificationLabel")
@onready var cover_layer = get_node_or_null("CoverLayer")
@onready var cover_screen = get_node_or_null("CoverLayer/CoverScreen")
@onready var cover_prompt = get_node_or_null("CoverLayer/CoverScreen/CoverPrompt")

var next_serve_right: bool = true
var prompt_tween: Tween = null

## Perfiles de Fósforo Vintage conmutables en tiempo real
const PHOSPHOR_PRESETS = [
	{"name": "P4 B&W Clásico", "tint": Color(0.92, 0.96, 1.0), "glow": 0.68},
	{"name": "P1 Fósforo Verde Arcade", "tint": Color(0.32, 1.0, 0.42), "glow": 0.95},
	{"name": "P3 Fósforo Ámbar Vintage", "tint": Color(1.0, 0.74, 0.20), "glow": 0.85},
	{"name": "Fósforo Cian Neón", "tint": Color(0.30, 0.95, 1.0), "glow": 0.80}
]
var current_preset_idx: int = 0
var crt_active: bool = true
var glow_level: int = 1 # 0: Suave, 1: Estándar, 2: Ultra Glow
const GLOW_MULTIPLIERS = [0.55, 1.0, 1.65]


## _ready inicializa conexiones y coloca el juego en su estado de arranque.
func _ready() -> void:
	# Delimitar cancha en paletas y bola
	if court != null:
		if player_paddle:
			player_paddle.set_bounds(court.top_wall_y, court.bottom_wall_y)
		if cpu_paddle:
			cpu_paddle.set_bounds(court.top_wall_y, court.bottom_wall_y)
			cpu_paddle.ball_ref = ball
		if ball:
			ball.set_court_bounds(court.top_wall_y, court.bottom_wall_y)

	# Conectar señales emitidas por la bola a los métodos de este script
	if ball:
		ball.scored.connect(_on_ball_scored)
		ball.paddle_hit.connect(_on_ball_paddle_hit)
		ball.wall_hit.connect(_on_ball_wall_hit)

	# Aplicar el perfil de fósforo P4 por defecto
	_apply_phosphor_preset(0, false)

	# Configuración de arranque: Portada exterior activa
	if cover_screen:
		if cover_layer:
			cover_layer.visible = true
		cover_screen.visible = true
		cover_screen.modulate.a = 1.0
		_start_prompt_pulse()
		current_state = State.COVER
	else:
		_reset_game()


## Inicia la animación de pulso infinito para el texto de la portada usando un Tween
func _start_prompt_pulse() -> void:
	if cover_prompt:
		if prompt_tween and prompt_tween.is_valid():
			prompt_tween.kill()
		prompt_tween = create_tween().set_loops()
		prompt_tween.tween_property(cover_prompt, "modulate:a", 0.30, 0.55)
		prompt_tween.tween_property(cover_prompt, "modulate:a", 1.0, 0.55)


## =============================================================================
## _input(): Captura global prioritaria
##
## Aquí se manejan dos reglas fundamentales solicitadas:
## 1. Si se pulsa ESC durante el juego -> reiniciar y volver a la portada.
## 2. En la portada -> solo se sale con clic o tecla (se descarta el scroll del ratón).
## =============================================================================
func _input(event: InputEvent) -> void:
	# ESC en cualquier momento de la partida regresa a la portada y resetea el juego
	if current_state != State.COVER:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_return_to_cover()
			var vp = get_viewport()
			if vp:
				vp.set_input_as_handled()
			return

	# Control estricto de salida en la portada:
	# Se admiten clics de ratón (izq/der), pulsaciones de tecla y toques táctiles.
	# Se excluye explícitamente el giro de la rueda del ratón (Mouse Scroll).
	if current_state == State.COVER:
		var is_click: bool = false
		if event is InputEventMouseButton and event.pressed:
			if event.button_index != MOUSE_BUTTON_WHEEL_UP and \
			   event.button_index != MOUSE_BUTTON_WHEEL_DOWN and \
			   event.button_index != MOUSE_BUTTON_WHEEL_LEFT and \
			   event.button_index != MOUSE_BUTTON_WHEEL_RIGHT:
				is_click = true

		var is_key: bool = event is InputEventKey and event.pressed
		var is_touch: bool = event is InputEventScreenTouch and event.pressed

		if is_click or is_key or is_touch:
			_dismiss_cover()
			var vp = get_viewport()
			if vp:
				vp.set_input_as_handled()
			return


## Oculta la portada con una animación fade-out y entra al estado IDLE listo para jugar
func _dismiss_cover() -> void:
	current_state = State.IDLE
	if prompt_tween and prompt_tween.is_valid():
		prompt_tween.kill()
	if audio_manager:
		audio_manager.play_paddle() # Feedback sonoro retro
	if cover_screen:
		var fade = create_tween()
		fade.tween_property(cover_screen, "modulate:a", 0.0, 0.30)
		fade.tween_callback(func():
			cover_screen.visible = false
			if cover_layer:
				cover_layer.visible = false
		)
	_reset_game()


## Restablece el juego y muestra de nuevo el cartel exterior de la portada
func _return_to_cover() -> void:
	current_state = State.COVER
	if ball:
		ball.stop()
		ball.position = Vector2(400, 300)
	player_score = 0
	cpu_score = 0
	if player_score_display:
		player_score_display.value = 0
	if cpu_score_display:
		cpu_score_display.value = 0
	if player_paddle:
		player_paddle.position.y = 300
		player_paddle.target_y = 300
	if cpu_paddle:
		cpu_paddle.position.y = 300
	if message_label:
		message_label.visible = false
	if sub_label:
		sub_label.visible = false

	if audio_manager:
		audio_manager.play_wall()

	if cover_layer:
		cover_layer.visible = true
	if cover_screen:
		cover_screen.visible = true
		cover_screen.modulate.a = 0.0
		var fade_in = create_tween()
		fade_in.tween_property(cover_screen, "modulate:a", 1.0, 0.25)
	_start_prompt_pulse()


## Aplica el perfil de color y glow de fósforo al ShaderMaterial del CRT
func _apply_phosphor_preset(idx: int, show_notify: bool = true) -> void:
	current_preset_idx = idx % PHOSPHOR_PRESETS.size()
	var preset = PHOSPHOR_PRESETS[current_preset_idx]
	if crt_rect and crt_rect.material is ShaderMaterial:
		var mat = crt_rect.material as ShaderMaterial
		mat.set_shader_parameter("phosphor_tint", preset["tint"])
		var base_glow = preset["glow"] * GLOW_MULTIPLIERS[glow_level]
		mat.set_shader_parameter("glow_intensity", base_glow)
	if show_notify:
		_show_notification("MODO FÓSFORO: " + preset["name"])


## Muestra un banner temporal con fade-out automático informando del ajuste realizado
func _show_notification(text: String) -> void:
	if notification_label:
		notification_label.text = text
		notification_label.visible = true
		var tween = create_tween()
		tween.tween_property(notification_label, "modulate:a", 1.0, 0.1)
		tween.tween_interval(1.8)
		tween.tween_property(notification_label, "modulate:a", 0.0, 0.6)


## Reinicia las posiciones, marcadores y etiquetas del juego
func _reset_game() -> void:
	player_score = 0
	cpu_score = 0
	if player_score_display:
		player_score_display.value = 0
	if cpu_score_display:
		cpu_score_display.value = 0
	if ball:
		ball.stop()
		ball.position = Vector2(400, 300)
	if player_paddle:
		player_paddle.position.y = 300
		player_paddle.target_y = 300
	if cpu_paddle:
		cpu_paddle.position.y = 300
	current_state = State.IDLE

	if message_label:
		message_label.text = "PONG"
		message_label.visible = true
	if sub_label:
		sub_label.text = "GIRA EL SCROLL O HAZ CLIC PARA SERVIR\n[1-4] FÓSFORO | [C] CRT | [G] GLOW | [ESC] PORTADA"
		sub_label.visible = true
	if controls_label:
		controls_label.text = "SCROLL: MOVER PALETA | [1-4] FÓSFORO | [C] CRT | [G] GLOW | [ESC] PORTADA"


## =============================================================================
## _unhandled_input(): Atiende eventos de teclado y ratón durante el juego
## =============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.COVER:
		return

	# Teclas numéricas para cambiar paleta de fósforo y atajos CRT
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_apply_phosphor_preset(0)
				return
			KEY_2:
				_apply_phosphor_preset(1)
				return
			KEY_3:
				_apply_phosphor_preset(2)
				return
			KEY_4:
				_apply_phosphor_preset(3)
				return
			KEY_C:
				crt_active = !crt_active
				if crt_rect and crt_rect.material is ShaderMaterial:
					(crt_rect.material as ShaderMaterial).set_shader_parameter("crt_enabled", crt_active)
				_show_notification("FILTRO CRT: " + ("ACTIVADO" if crt_active else "DESACTIVADO"))
				return
			KEY_G:
				glow_level = (glow_level + 1) % 3
				var glow_names = ["SUAVE", "ESTÁNDAR", "ULTRA GLOW"]
				_apply_phosphor_preset(current_preset_idx)
				_show_notification("GLOW FÓSFORO: " + glow_names[glow_level])
				return

	# Iniciar el punto desde IDLE o reiniciar tras GAME_OVER
	if current_state == State.IDLE:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			_start_point()
	elif current_state == State.GAME_OVER:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			_reset_game()


## Ejecuta las colisiones físicas en cada paso del motor de física
func _physics_process(_delta: float) -> void:
	if current_state == State.PLAYING and ball != null:
		if player_paddle:
			ball.check_paddle_collision(player_paddle)
		if cpu_paddle:
			ball.check_paddle_collision(cpu_paddle)


## Inicia el saque de la bola
func _start_point() -> void:
	current_state = State.PLAYING
	if message_label:
		message_label.visible = false
	if sub_label:
		sub_label.visible = false
	if ball:
		ball.serve(next_serve_right)


## Atiende la señal 'scored' emitida por la bola cuando un jugador anota
func _on_ball_scored(scorer: String) -> void:
	if audio_manager:
		audio_manager.play_score()
	if scorer == "player":
		player_score += 1
		if player_score_display:
			player_score_display.value = player_score
		next_serve_right = false # Saca hacia la CPU
	else:
		cpu_score += 1
		if cpu_score_display:
			cpu_score_display.value = cpu_score
		next_serve_right = true  # Saca hacia el Jugador

	# Comprobación de condición de victoria (11 puntos)
	if player_score >= WINNING_SCORE or cpu_score >= WINNING_SCORE:
		_game_over(player_score >= WINNING_SCORE)
	else:
		current_state = State.POINT_SCORED
		# Breve pausa dramática de 1.0 segundo antes del próximo saque
		await get_tree().create_timer(1.0).timeout
		if current_state == State.POINT_SCORED:
			_start_point()


## Muestra el mensaje de fin de partida
func _game_over(player_won: bool) -> void:
	current_state = State.GAME_OVER
	if ball:
		ball.stop()
	if message_label:
		if player_won:
			message_label.text = "¡JUGADOR GANA!"
		else:
			message_label.text = "¡COMPUTADORA GANA!"
		message_label.visible = true
	if sub_label:
		sub_label.text = "GIRA EL SCROLL O CLIC PARA REINICIAR | [ESC] PORTADA"
		sub_label.visible = true


## Atiende la señal 'paddle_hit' para disparar el sonido correspondiente
func _on_ball_paddle_hit() -> void:
	if audio_manager:
		audio_manager.play_paddle()


## Atiende la señal 'wall_hit' para disparar el sonido correspondiente
func _on_ball_wall_hit() -> void:
	if audio_manager:
		audio_manager.play_wall()
