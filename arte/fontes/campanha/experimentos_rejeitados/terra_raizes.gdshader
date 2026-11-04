shader_type canvas_item;
// Piso contínuo: raízes atravessam as células e também seguem sob a floresta.
uniform sampler2D terra : source_color, filter_linear_mipmap, repeat_disable;
varying vec2 mundo;
varying vec4 tom;
void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
	tom = COLOR;
}
void fragment() {
	// Repetição espelhada mantém a mesma raiz nos dois lados de cada junção.
	vec2 uv = 1.0-abs(mod(mundo/128.0,2.0)-1.0);
	COLOR = vec4(texture(terra,uv).rgb,1.0)*tom;
}
