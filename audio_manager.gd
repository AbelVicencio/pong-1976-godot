## audio_manager.gd
## =============================================================================
## Gestor de Audio Procedural para Pong 1976 (Atari Clone)
##
## CONCEPTO GODOT:
## En lugar de requerir archivos externos (.wav o .ogg), este script sintetiza
## efectos de sonido clásicos de 8 bits en tiempo de ejecución generando búferes
## de bytes en memoria utilizando la clase AudioStreamWAV.
## =============================================================================
extends Node

# Reproductores de audio dedicados para cada tipo de efecto sonoro.
# Usar reproductores separados evita que un sonido interrumpa abruptamente a otro.
var paddle_player: AudioStreamPlayer
var wall_player: AudioStreamPlayer
var score_player: AudioStreamPlayer

# Almacenan los flujos de audio (AudioStreamWAV) generados en memoria.
var paddle_sound: AudioStreamWAV
var wall_sound: AudioStreamWAV
var score_sound: AudioStreamWAV


## _ready() se ejecuta automáticamente cuando el nodo entra al SceneTree.
## Es el lugar ideal para inicializar recursos y crear nodos hijos programáticamente.
func _ready() -> void:
	# Frecuencias históricas del chip de sonido del Pong original de Atari:
	# - Paleta: Tono medio/agudo (~490 Hz), duración corta.
	# - Pared: Tono grave (~226 Hz), duración corta.
	# - Tanto/Fallo: Zumbido grave (~125 Hz), duración más prolongada.
	paddle_sound = _generate_tone(490.0, 0.08, 0.45)
	wall_sound = _generate_tone(226.0, 0.08, 0.45)
	score_sound = _generate_tone(125.0, 0.32, 0.5)

	# Instanciamos los reproductores de audio
	paddle_player = AudioStreamPlayer.new()
	wall_player = AudioStreamPlayer.new()
	score_player = AudioStreamPlayer.new()

	# Asignamos los flujos sintetizados a cada reproductor
	paddle_player.stream = paddle_sound
	wall_player.stream = wall_sound
	score_player.stream = score_sound

	# add_child() agrega los nodos hijos a este nodo en el árbol de escenas.
	add_child(paddle_player)
	add_child(wall_player)
	add_child(score_player)


## Reproduce el beep de contacto con la paleta.
func play_paddle() -> void:
	if paddle_player.playing:
		paddle_player.stop()
	paddle_player.play()


## Reproduce el beep de rebote contra los muros superior e inferior.
func play_wall() -> void:
	if wall_player.playing:
		wall_player.stop()
	wall_player.play()


## Reproduce el tono grave de punto anotado / fallo.
func play_score() -> void:
	if score_player.playing:
		score_player.stop()
	score_player.play()


## =============================================================================
## Síntesis Procedural de Onda Cuadrada (8-Bit Retro Sound)
##
## Parámetros:
##   - freq: Frecuencia fundamental del tono en Hertz (Hz).
##   - duration: Duración total del sonido en segundos.
##   - volume: Amplitud normalizada entre 0.0 y 1.0.
##
## Retorna:
##   Un objeto AudioStreamWAV listo para ser reproducido por AudioStreamPlayer.
## =============================================================================
func _generate_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS # Formato 8 bits mono (retro)
	stream.mix_rate = 22050                     # Tasa de muestreo de 22.05 kHz
	stream.stereo = false                       # Canal único (mono)

	var total_samples = int(stream.mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)

	# Cantidad de muestras reservadas para una suave caída al final (fade-out).
	# Esto previene el clásico chasquido o 'pop' de audio al detener la onda abruptamente.
	var fade_samples = int(stream.mix_rate * 0.01) # 10 milisegundos

	for i in range(total_samples):
		var t = float(i) / float(stream.mix_rate)

		# Onda cuadrada: positiva en la primera mitad del ciclo, negativa en la segunda.
		var phase = fposmod(t * freq, 1.0)
		var val = 1.0 if phase < 0.5 else -1.0

		# Envolvente de volumen lineal en la cola del sonido
		var env = 1.0
		if i > total_samples - fade_samples:
			env = float(total_samples - i) / float(fade_samples)

		var sample_val = val * volume * env
		# Convertimos el rango flotante [-1.0, 1.0] a byte sin signo de 8 bits [0, 255]
		var byte_val = int(clamp((sample_val * 127.0) + 128.0, 0.0, 255.0))
		data[i] = byte_val

	stream.data = data
	return stream
