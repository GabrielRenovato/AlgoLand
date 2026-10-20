shader_type canvas_item;
uniform bool recortar = false;
uniform float topo = -100000.0;
uniform float base = 100000.0;
varying float altura_mundo;
void vertex() {
    altura_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}
void fragment() {
    if (recortar && (altura_mundo < topo || altura_mundo > base)) { discard; }
}
