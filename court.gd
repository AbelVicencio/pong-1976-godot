## court.gd
## =============================================================================
## Renderizado Gráfico de la Cancha de Juego Pong 1976
##
## CONCEPTO GODOT:
## Un nodo Node2D ligero que dibuja los elementos estáticos de la cancha
## (muros superior e inferior, y la clásica red divisoria discontinua) usando
## la función _draw(). Al no usar imágenes externas, el renderizado es
## vectorialmente nítido a cualquier resolución de ventana.
## =============================================================================
extends Node2D

## Posiciones en Y de las paredes superior e inferior
@export var top_wall_y: float = 24.0
@export var bottom_wall_y: float = 576.0

## Grosor de las paredes horizontales
@export var wall_thickness: float = 12.0

## Dimensiones de los segmentos de la red divisoria central
@export var net_width: float = 6.0
@export var net_segment_height: float = 12.0
@export var net_gap: float = 12.0


## _draw() se invoca cuando el nodo necesita redibujarse.
func _draw() -> void:
	# Muro superior (ancho de 800 píxeles, alto de 12 píxeles)
	draw_rect(Rect2(0, top_wall_y - wall_thickness, 800, wall_thickness), Color.WHITE)

	# Muro inferior
	draw_rect(Rect2(0, bottom_wall_y, 800, wall_thickness), Color.WHITE)

	# Red divisoria central discontinua (Dashed Net)
	var current_y = top_wall_y + 4.0
	var net_x = 400.0 - (net_width / 2.0)

	while current_y < bottom_wall_y - 4.0:
		var seg_h = min(net_segment_height, bottom_wall_y - 4.0 - current_y)
		draw_rect(Rect2(net_x, current_y, net_width, seg_h), Color.WHITE)
		current_y += net_segment_height + net_gap
