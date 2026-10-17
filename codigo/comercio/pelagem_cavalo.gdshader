shader_type canvas_item;

// A pelagem usa tons neutros; couro e fivelas conservam as cores do sprite.
uniform int pelagem : hint_range(0, 2) = 1;
varying vec4 cor_do_sprite;

void vertex() {
	cor_do_sprite = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float maior = max(pixel.r, max(pixel.g, pixel.b));
	float menor = min(pixel.r, min(pixel.g, pixel.b));
	float luz = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	// Crina, cauda, cascos e contornos escuros mantêm a identidade nas três pelagens.
	if (pelagem != 2 && maior - menor < 0.12 && luz > 0.42) {
		float tom = clamp((luz - 0.22) / 0.74, 0.0, 1.0);
		vec3 sombra = pelagem == 0 ? vec3(0.08, 0.09, 0.12) : vec3(0.27, 0.14, 0.08);
		vec3 brilho = pelagem == 0 ? vec3(0.34, 0.37, 0.42) : vec3(0.72, 0.43, 0.22);
		pixel.rgb = mix(sombra, brilho, tom);
	}
	COLOR = pixel * cor_do_sprite;
}
