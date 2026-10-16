shader_type canvas_item;

uniform sampler2D mascara_piso : filter_nearest, repeat_disable;
uniform vec2 tamanho_mascara = vec2(1.0);
varying vec2 ponto;
varying vec4 tom;

void vertex() {
	ponto = VERTEX;
	tom = COLOR;
}

void fragment() {
	vec2 celula = floor(ponto / 16.0);
	if (all(greaterThanEqual(celula, vec2(0.0))) && all(lessThan(celula, tamanho_mascara))) {
		if (texture(mascara_piso, (celula + 0.5) / tamanho_mascara).r > 0.5) {
			discard;
		}
	}
	COLOR = texture(TEXTURE, UV) * tom;
}
