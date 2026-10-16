shader_type canvas_item;
#include "res://codigo/cenario/acabamento_tiles.gdshaderinc"
uniform float intensidade_acabamento : hint_range(0.0, 1.0) = 1.0;
uniform vec4 recorte = vec4(176.0, 208.0, 16.0, 16.0);
varying vec2 ponto;
varying vec4 tom;
void vertex() {
	ponto = VERTEX;
	tom = COLOR;
}
void fragment() {
	vec2 celula = fract(ponto / 16.0);
	vec2 pixel = (floor(celula * 16.0) + vec2(0.5)) / 16.0;
	vec2 uv_agua = (recorte.xy + pixel * recorte.zw) * TEXTURE_PIXEL_SIZE;
	COLOR = acabamento_tile(texture(TEXTURE, uv_agua), intensidade_acabamento) * tom;
}
