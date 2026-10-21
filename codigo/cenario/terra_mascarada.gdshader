shader_type canvas_item;
#include "res://codigo/cenario/acabamento_tiles.gdshaderinc"

uniform float intensidade_acabamento : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D campo_terra : filter_nearest, repeat_enable;
uniform sampler2D mascara_terra : filter_nearest, repeat_disable;
varying vec2 ponto_mundo;
varying vec4 modulacao;

void vertex() {
	ponto_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulacao = COLOR;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 mascara = texture(mascara_terra, UV);
	vec3 terra = texture(campo_terra, (floor(ponto_mundo) + vec2(0.5)) / 128.0).rgb;
	COLOR = acabamento_tile(vec4(mix(original.rgb, terra * mascara.g, mascara.r), original.a), intensidade_acabamento) * modulacao;
}
