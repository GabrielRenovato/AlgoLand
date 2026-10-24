shader_type canvas_item;
uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 periodo = vec2(128.0);
uniform bool usar_uv = false;
uniform vec2 folha;
varying vec2 mundo;
varying vec4 tom;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; tom = COLOR; }
void fragment() {
	vec2 p = usar_uv ? UV * folha : mundo;
	COLOR = texture(arte, p / periodo) * tom;
}
