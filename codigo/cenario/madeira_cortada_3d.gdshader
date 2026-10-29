shader_type spatial;
render_mode cull_disabled;
uniform vec4 cor : source_color=vec4(.74,.53,.28,1.);
varying vec3 ponto;
void vertex(){ponto=VERTEX;}
void fragment(){
 vec2 p=floor(ponto.xz*90.)/90.;
 float angulo=atan(p.y,p.x);
 float raio=length(p)+sin(angulo*5.)*.007;
 float anel=step(.72,fract(raio/.044));
 float fissura=step(.985,abs(sin(angulo*2.5)))*step(.09,raio);
 ALBEDO=cor.rgb*(1.-anel*.24-fissura*.32);
 ROUGHNESS=1.;SPECULAR=0.;
}
void light(){
 float n=max(dot(NORMAL,LIGHT),0.);
 DIFFUSE_LIGHT+=LIGHT_COLOR*ATTENUATION*(n<.25 ? .60 : (n<.65 ? .82 : 1.))/PI;
}
