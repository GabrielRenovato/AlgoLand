shader_type canvas_item;
uniform sampler2D superficie : filter_linear, repeat_disable;
uniform sampler2D altura : filter_linear, repeat_disable;
varying vec4 tom;
void vertex() { tom=COLOR; }
void fragment() {
	vec2 texel=vec2(1.0/96.0);
	float h=texture(altura,UV).r-.5;
	vec2 normal=vec2(texture(altura,UV+vec2(texel.x,0)).r-texture(altura,UV-vec2(texel.x,0)).r,texture(altura,UV+vec2(0,texel.y)).r-texture(altura,UV-vec2(0,texel.y)).r);
	float m=texture(superficie,UV).r;
	vec2 desvio=normal*.065+vec2(h*.006,h*.009);
	vec2 uv=UV+desvio;
	float dentro=texture(superficie,uv).r;
	vec4 base=texture(TEXTURE,UV);
	vec3 agua=texture(TEXTURE,mix(UV,uv,step(.65,dentro))).rgb;
	float luz=clamp((normal.x-normal.y)*3.0,-.22,.22);
	agua=clamp(agua*(1.0+luz)+vec3(.30,.52,.61)*max(0.0,luz)*.45,vec3(0),vec3(1));
	COLOR=vec4(mix(base.rgb,agua,m),base.a)*tom;
}
