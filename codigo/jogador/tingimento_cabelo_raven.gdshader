shader_type canvas_item;
varying vec4 tinta;
void vertex() { tinta = COLOR; }
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float luz = clamp(dot(original.rgb, vec3(0.299,0.587,0.114))*1.5,0.0,1.0);
	vec3 cor = distance(tinta.rgb,vec3(1.0)) < 0.005 ? original.rgb : vec3(luz)*tinta.rgb;
	COLOR = vec4(cor,original.a*tinta.a);
}
