shader_type canvas_item;
uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform vec4 recorte;
varying vec4 tom;
void vertex() { tom = COLOR; }
void fragment() {
	vec2 p = (UV - origem) / tamanho;
	float dentro = step(0.0, p.x) * step(0.0, p.y) * step(p.x, 1.0) * step(p.y, 1.0);
	vec4 cor = texture(arte, recorte.xy + p * recorte.zw);
	COLOR = vec4(cor.rgb, cor.a * dentro) * tom;
}
