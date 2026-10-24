shader_type canvas_item;
uniform float calor : hint_range(0.0,1.0) = 0.0;
varying vec4 tinta;
void vertex() { tinta = COLOR; }
void fragment() {
 vec4 metal = texture(TEXTURE,UV);
 float cinza = dot(metal.rgb,vec3(0.3,0.5,0.2));
 vec3 frio = vec3(cinza*0.58+0.08,cinza*0.60+0.08,cinza*0.65+0.09);
 COLOR = vec4(mix(frio,metal.rgb,calor),metal.a)*tinta;
}
