shader_type canvas_item;
uniform int estacao = 0;
varying vec4 tom;
void vertex() {
 tom = COLOR;
}
void fragment() {
 vec2 uv_pixel = (floor(UV * 64.0) + vec2(0.5)) / 64.0;
 vec4 c = texture(TEXTURE, uv_pixel) * tom;
 float verde = smoothstep(0.02, 0.16, c.g - max(c.r, c.b));
 float luz = dot(c.rgb, vec3(0.3, 0.59, 0.11));
 if (estacao == 2) {
  c.rgb = mix(c.rgb, vec3(luz * 1.18, luz * 0.95, luz * 0.55), verde * 0.75);
 } else if (estacao == 3) {
  c.rgb = mix(c.rgb, vec3(0.68 + luz * 0.3, 0.74 + luz * 0.25, 0.83 + luz * 0.17), verde);
 }
 COLOR = c;
}
