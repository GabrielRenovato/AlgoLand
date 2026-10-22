shader_type canvas_item;
uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_enable;
uniform int estacao = 0;
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
 // Mesma fase nas plataformas, sem frestas entre tiles.
 COLOR = vec4(texture(arte,mundo/128.0).rgb, 1.0);
}
