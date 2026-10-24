shader_type canvas_item;
// Brasa e pequenas chamas variam sem desmontar o desenho da pedra ou da coifa.
uniform sampler2D fria : source_color, filter_linear;
uniform float instante = 0.0;
uniform float ar : hint_range(0.0,1.0) = 0.0;
uniform vec4 boca = vec4(80.0,104.0,60.0,29.0);
varying vec4 tinta;
void vertex() { tinta = COLOR; }
void fragment() {
 vec4 base = texture(TEXTURE,UV);
 vec2 p = UV/TEXTURE_PIXEL_SIZE;
 vec2 dentro = (p-boca.xy)/boca.zw;
 if (all(greaterThan(dentro,vec2(0.0))) && all(lessThan(dentro,vec2(1.0)))) {
  float calor = smoothstep(0.25,0.8,base.r-base.b)*smoothstep(0.45,0.9,base.r);
  float borda = smoothstep(0.0,0.12,dentro.x)*smoothstep(0.0,0.12,1.0-dentro.x)*smoothstep(0.0,0.14,dentro.y)*smoothstep(0.0,0.14,1.0-dentro.y);
  float t = floor(instante*12.0)/12.0;
  vec2 onda = vec2(sin(p.y*0.08+t*7.0)*1.2,cos(p.x*0.07+t*6.0)*1.8);
  vec4 movido = texture(TEXTURE,UV+onda*TEXTURE_PIXEL_SIZE);
  base.rgb = mix(base.rgb,movido.rgb,calor*borda*0.6);
  float altura = mix(boca.y+boca.w*0.88,boca.y+3.0,ar);
  float aceso = smoothstep(altura-4.0,altura+5.0,p.y)*(0.15+ar*0.85);
  vec3 frio = texture(fria,UV).rgb;
  base.rgb = mix(frio,base.rgb,aceso);
  base.rgb *= 1.0+calor*borda*(sin(t*9.0+p.x*0.07)*0.09+ar*0.18);
 }
 COLOR=base*tinta;
}
