shader_type canvas_item;
uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 uv_origem = vec2(0.0);
uniform vec2 uv_tamanho = vec2(1.0);
varying vec4 tom;
void vertex() { tom=COLOR; }
void fragment() { COLOR=texture(arte,(UV-uv_origem)/uv_tamanho)*tom; }
