shader_type canvas_item;

uniform sampler2D mascara_agua : filter_nearest;
uniform sampler2D fundo_pedras : source_color, filter_nearest, repeat_enable;
uniform float fase_agua = 0.0;
varying vec4 tom;
varying vec2 ponto;

void vertex() {
	tom = COLOR;
	ponto = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	float agua = texture(mascara_agua, UV).r;
	vec2 pixel = floor(ponto);
	vec3 pedras = texture(fundo_pedras, (pixel + vec2(0.5)) / vec2(textureSize(fundo_pedras, 0))).rgb;
	cor.rgb = mix(cor.rgb, mix(pedras, vec3(0.25, 0.45, 0.41), 0.24), agua);
	vec2 celula = floor(pixel / vec2(8.0, 6.0));
	vec2 dentro = mod(pixel, vec2(8.0, 6.0));
	float semente = fract(sin(dot(celula, vec2(12.9898, 78.233))) * 43758.5453);
	float pulso = step(0.75, semente) * smoothstep(0.1, 0.8, sin(fase_agua * 0.785398 + semente * 6.283185));
	float traco = step(1.0, dentro.x) * (1.0 - step(4.0, dentro.x)) * (1.0 - step(1.0, abs(dentro.y - 2.0)));
	// A máscara só libera reflexos na água; leito, margens e contornos continuam no lugar.
	cor.rgb = mix(cor.rgb, vec3(0.67, 0.82, 0.77), agua * pulso * traco * 0.65);
	COLOR = cor * tom;
}
