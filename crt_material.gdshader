// =============================================================================
// crt_material.gdshader
// Shader de Simulación de Televisor CRT Vintage (Tubo de Rayos Catódicos)
// =============================================================================
// CONCEPTOS GODOT SHADER:
// - shader_type canvas_item: Aplica a nodos 2D y de interfaz gráfica (UI).
// - hint_screen_texture: Permite leer el búfer de pantalla completo renderizado
//   previamente detrás de este nodo (captura de frame).
// - filter_linear_mipmap: Aplica filtrado bilineal con mipmaps para un muestreo
//   suave y sin artefactos parpadeantes al escalar.
// =============================================================================
shader_type canvas_item;

// Textura de pantalla completa capturada por el motor gráfico
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- Parámetros de Geometría y Curvatura del Tubo ---
// warp_amount: Intensidad de distorsión convexa tipo barril (barrel distortion).
uniform float warp_amount : hint_range(0.0, 0.2) = 0.055;
// corner_radius: Radio de redondeo de las esquinas del cristal del televisor.
uniform float corner_radius : hint_range(0.0, 0.2) = 0.045;

// --- Scanlines y Rejilla de Fósforo ---
// scanline_count: Cantidad total de líneas de barrido horizontal (240 para resolución 240p).
uniform float scanline_count : hint_range(120.0, 480.0) = 240.0;
// scanline_intensity: Oscurecimiento entre cada línea de barrido del haz de electrones.
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.28;
// grille_intensity: Micro-rejilla vertical de apertura (Aperture Grille / Shadow Mask).
uniform float grille_intensity : hint_range(0.0, 1.0) = 0.10;

// --- Glow de Fósforo y Halación ---
// glow_intensity: Fuerza del resplandor de halación sobre elementos iluminados.
uniform float glow_intensity : hint_range(0.0, 3.0) = 0.68;
// glow_radius: Radio de dispersión óptica del haz en el cristal.
uniform float glow_radius : hint_range(0.001, 0.01) = 0.0032;
// chromatic_aberration: Desplazamiento de los canales Rojo y Azul en los bordes.
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0018;

// --- Dinámica y Viñeta ---
// flicker_intensity: Micro-parpadeo de frecuencia de refresco de 60 Hz.
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.015;
// vignette_power: Oscurecimiento periférico natural por curvatura esférica de la lente.
uniform float vignette_power : hint_range(0.0, 2.0) = 0.45;

// --- Color del Fósforo y Ganancia ---
uniform vec3 phosphor_tint : source_color = vec3(0.92, 0.96, 1.0);
uniform float brightness_boost : hint_range(0.5, 2.5) = 1.12;

// Interruptor maestro para activar/desactivar el filtro en caliente
uniform bool crt_enabled = true;


// =============================================================================
// warp(): Deforma las coordenadas UV simulando la superficie esférica del tubo
// =============================================================================
vec2 warp(vec2 uv) {
	vec2 dc = uv - 0.5;
	float d = dot(dc, dc);
	return 0.5 + dc * (1.0 + warp_amount * d * 4.0);
}


// =============================================================================
// rounded_box(): Función de Distancia con Signo (SDF) para una caja con esquinas
// redondeadas. Retorna distancia > 0 fuera de la caja, < 0 dentro.
// =============================================================================
float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}


// =============================================================================
// fragment(): Procesador de píxeles ejecutado por la GPU para cada píxel
// =============================================================================
void fragment() {
	if (!crt_enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// 1. Deformación geométrica de las coordenadas UV
		vec2 uv = warp(SCREEN_UV);

		// 2. Comprobación del marco exterior del mueble / bisel
		vec2 centered = uv - 0.5;
		float border = rounded_box(centered, vec2(0.485, 0.485), corner_radius);

		if (border > 0.0 || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			// Exterior del cristal: plástico negro del marco del mueble (chassis bezel)
			COLOR = vec4(0.01, 0.01, 0.015, 1.0);
		} else {
			// 3. Aberración Cromática: Desfasaje de los canales R y B en función de la distancia al centro
			vec2 ca_offset = vec2(chromatic_aberration * (uv.x - 0.5), 0.0);
			vec4 base_color;
			base_color.r = texture(screen_texture, uv + ca_offset).r;
			base_color.g = texture(screen_texture, uv).g;
			base_color.b = texture(screen_texture, uv - ca_offset).b;
			base_color.a = 1.0;

			// 4. Muestreo de Halación / Phosphor Bloom (muestreo en estrella de 8 puntos)
			vec4 glow = vec4(0.0);
			glow += texture(screen_texture, uv + vec2(-glow_radius, -glow_radius));
			glow += texture(screen_texture, uv + vec2(glow_radius, -glow_radius));
			glow += texture(screen_texture, uv + vec2(-glow_radius, glow_radius));
			glow += texture(screen_texture, uv + vec2(glow_radius, glow_radius));
			glow += texture(screen_texture, uv + vec2(0.0, -glow_radius * 1.5));
			glow += texture(screen_texture, uv + vec2(0.0, glow_radius * 1.5));
			glow += texture(screen_texture, uv + vec2(-glow_radius * 1.5, 0.0));
			glow += texture(screen_texture, uv + vec2(glow_radius * 1.5, 0.0));
			glow /= 8.0;

			// Combinación del color base con el resplandor de halación
			vec3 col = base_color.rgb + glow.rgb * glow_intensity;
			col *= brightness_boost;

			// 5. Scanlines del cañón de electrones (onda sinusoidal vertical)
			float scanline = sin(uv.y * scanline_count * 3.14159265);
			scanline = (scanline + 1.0) * 0.5;
			col *= 1.0 - (scanline * scanline_intensity);

			// 6. Rejilla de fósforo vertical (Aperture Grille)
			float grille = fract(FRAGCOORD.x * 0.3333);
			col *= 1.0 - (grille_intensity * (grille < 0.5 ? 0.0 : 1.0));

			// 7. Micro-parpadeo de frecuencia de refresco de 60 Hz
			float flicker = 1.0 + sin(TIME * 60.0) * flicker_intensity;
			col *= flicker;

			// 8. Tinte del perfil de fósforo (P4 B&W, P1 Verde, P3 Ámbar o Cian)
			col *= phosphor_tint;

			// 9. Viñeta: Caída de luminosidad hacia los extremos por la curvatura del vidrio
			float vig = (1.0 - abs(centered.x * 2.0)) * (1.0 - abs(centered.y * 2.0));
			vig = clamp(vig * 3.2, 0.0, 1.0);
			vig = pow(vig, vignette_power);
			col *= vig;

			// 10. Sombra interior del bisel de la pantalla
			float edge_shadow = clamp(-border * 60.0, 0.0, 1.0);
			col *= edge_shadow;

			COLOR = vec4(col, 1.0);
		}
	}
}
