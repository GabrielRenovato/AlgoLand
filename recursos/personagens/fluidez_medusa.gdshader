shader_type canvas_item;

// Os vetores descrevem deslocamentos entre poses; a arte permanece intacta.
uniform sampler2D fluxo_frente : filter_linear, repeat_disable;
uniform sampler2D fluxo_volta : filter_linear, repeat_disable;
uniform vec2 celula = vec2(0.0);
uniform float progresso : hint_range(0.0, 1.0) = 0.0;
varying vec4 modulacao;

void vertex() {
	modulacao = COLOR;
}

vec2 deslocamento(sampler2D campo, vec2 ponto) {
	vec2 uv = (celula + clamp(ponto / 160.0, vec2(0.00625), vec2(0.99375))) / vec2(6.0, 4.0);
	return (texture(campo, uv).rg * 255.0 - 128.0) * (64.0 / 127.0);
}

vec4 amostrar(sampler2D arte, vec2 origem, vec2 ponto) {
	if (any(lessThan(ponto, vec2(0.0))) || any(greaterThanEqual(ponto, vec2(160.0)))) {
		return vec4(0.0);
	}
	// Amostragem no centro do pixel: sem borrar ou misturar cores das poses.
	return texture(arte, (origem + (floor(ponto) + 0.5) / 160.0) / vec2(6.0, 4.0));
}

void fragment() {
	vec2 ponto = (UV * vec2(6.0, 4.0) - celula) * 160.0;
	vec2 seguinte = vec2(mod(celula.x + 1.0, 6.0), celula.y);
	vec4 cor;
	if (progresso < 0.5) {
		vec2 origem = ponto - progresso * deslocamento(fluxo_frente, ponto);
		for (int i = 0; i < 3; i++) {
			origem = mix(origem, ponto - progresso * deslocamento(fluxo_frente, origem), 0.5);
		}
		cor = amostrar(TEXTURE, celula, origem);
	} else {
		vec2 origem = ponto - (1.0 - progresso) * deslocamento(fluxo_volta, ponto);
		for (int i = 0; i < 3; i++) {
			origem = mix(origem, ponto - (1.0 - progresso) * deslocamento(fluxo_volta, origem), 0.5);
		}
		cor = amostrar(TEXTURE, seguinte, origem);
	}
	COLOR = cor * modulacao;
}
