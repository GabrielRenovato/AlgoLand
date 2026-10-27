shader_type canvas_item;
// A mesma composição das quatro camadas, em uma passagem no Android.
// Não usar unshaded: o CanvasModulate da noite/estação continua valendo.
uniform sampler2D chuva_forte : filter_nearest, repeat_enable;
uniform sampler2D chuva_leve : filter_nearest, repeat_enable;
uniform sampler2D neve_forte : filter_nearest, repeat_enable;
uniform sampler2D neve_leve : filter_nearest, repeat_enable;
uniform vec4 alfas = vec4(0.0);
uniform vec2 repeticoes = vec2(1.0);
varying vec4 modulacao;
void vertex() { modulacao = COLOR; }
vec4 sobre(vec4 base, vec4 topo, float opacidade) {
    float a = topo.a * opacidade;
    return vec4(topo.rgb * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
}
void fragment() {
    vec2 uv = UV * repeticoes;
    vec4 p = vec4(0.0);
    if (alfas.x > 0.001) { p = sobre(p, texture(chuva_forte, uv), alfas.x); }
    if (alfas.y > 0.001) { p = sobre(p, texture(chuva_leve, uv), alfas.y); }
    if (alfas.z > 0.001) { p = sobre(p, texture(neve_forte, uv), alfas.z); }
    if (alfas.w > 0.001) { p = sobre(p, texture(neve_leve, uv), alfas.w); }
    COLOR = vec4(p.rgb / max(p.a, 0.00001), p.a) * modulacao;
}
