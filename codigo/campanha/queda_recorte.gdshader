shader_type canvas_item;

// Queda do mapa regional: recorta pela linha do lábio do penhasco (coordenadas do quadro), esmaece o topo
// das quedas sem penhasco atrás e retrata a água com mais contraste, espuma nítida e fios correndo.
uniform vec2 labio_a;
uniform vec2 labio_b;
uniform float esmaecer_topo = 0.0;
uniform float altura_esmaecer = 110.0;
uniform float instante = -1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float massa = smoothstep(0.18, 0.55, t.a);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 cor = mix(vec3(lum), t.rgb, 1.25);
	cor = (cor - 0.5) * 1.08 + 0.5;
	vec2 d = labio_b - labio_a;
	float y_labio = labio_a.y + (local.x - labio_a.x) * (d.y / max(abs(d.x), 0.001)) * sign(d.x);
	float abaixo = local.y - y_labio;
	float alfa = massa * smoothstep(-0.5, 1.5, abaixo);
	alfa *= mix(1.0, smoothstep(0.0, altura_esmaecer, abaixo), esmaecer_topo);
	COLOR = vec4(cor, alfa * 0.93);
}
