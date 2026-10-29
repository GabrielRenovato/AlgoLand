shader_type spatial;
render_mode cull_disabled;
uniform vec4 cor : source_color = vec4(1.0);
uniform bool casca=false;
varying vec3 repouso;
varying vec3 tinta_folha;
void vertex(){repouso=VERTEX;tinta_folha=COLOR.rgb;}
void fragment(){
 vec3 p=floor(repouso*20.)/20.;
 float tinta=sin(p.x*32.+p.z*25.+sin(p.y*9.))*cos(p.z*28.-p.y*17.);
 float tom=tinta<-.36 ? .90 : (tinta>.36 ? 1.12 : 1.0);
 if(casca){
  float fibra=sin(atan(p.z,p.x)*12.+sin(p.y*5.)*.6);
  tom=fibra>.5 ? 1.14 : (fibra<-.65 ? .73 : 1.0);
 }
 ALBEDO=cor.rgb*tom*tinta_folha;ROUGHNESS=1.;SPECULAR=0.;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float tom=n<.05 ? .35 : (n<.5 ? .72 : 1.);
 DIFFUSE_LIGHT+=LIGHT_COLOR*ATTENUATION*tom/PI;
}
