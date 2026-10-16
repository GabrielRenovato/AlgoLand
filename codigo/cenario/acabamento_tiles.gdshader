shader_type canvas_item;
#include "res://codigo/cenario/acabamento_tiles.gdshaderinc"
uniform float intensidade_acabamento : hint_range(0.0, 1.0) = 1.0;
varying vec4 modulacao;
void vertex() {
	modulacao = COLOR;
}
void fragment() {
	COLOR = acabamento_tile(texture(TEXTURE, UV), intensidade_acabamento) * modulacao;
}
