shader_type canvas_item;
// Abre o vão na parede; a passagem reaproveita a entrada principal em escala menor.
uniform vec4 abertura = vec4(0.0);
varying vec2 ponto_local;
void vertex() {
    ponto_local = VERTEX;
}
void fragment() {
    if (ponto_local.x >= abertura.x && ponto_local.x < abertura.x + abertura.z
        && ponto_local.y >= abertura.y && ponto_local.y < abertura.y + abertura.w) {
        discard;
    }
}
