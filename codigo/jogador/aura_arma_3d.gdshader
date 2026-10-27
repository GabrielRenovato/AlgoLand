shader_type spatial;
// blend_mix conserva alfa no SubViewport transparente e na composição 2D final.
render_mode unshaded,blend_mix,cull_front,depth_draw_never,shadows_disabled;
uniform vec4 cor_brilho : source_color = vec4(.3,.8,1.,1.);
uniform float intensidade=0.;
uniform float largura=.03;
uniform float camada=1.;
uniform vec3 centro=vec3(0.);
uniform vec3 extensao=vec3(.1);
varying vec3 local;
void vertex(){
 local=VERTEX;
 // Expande também as arestas duras; mover só a normal separava as faces da caixa.
 vec3 radial=(VERTEX-centro)/max(extensao,vec3(.0001));
 VERTEX+=normalize(radial)*largura*camada;
}
void fragment(){
 float pulso=.82+.18*sin(TIME*4.+local.y*12.);
 float faixa=1.-smoothstep(.05,.23,abs(fract(local.y*2.-TIME*.75)-.5));
 ALBEDO=mix(cor_brilho.rgb,vec3(1.),faixa*.60)*1.6;
 ALPHA=intensidade*pulso*(.65+faixa*.30)/camada;
}
