shader_type spatial;
render_mode cull_disabled;
uniform vec4 cor : source_color = vec4(1.0);
varying vec3 repouso;
void vertex(){repouso=VERTEX;}
float tinta(vec3 p){return sin(p.x*17.0+p.y*7.0+sin(p.z*11.0))*sin(p.z*19.0-p.y*13.0);}
void fragment(){
 // Manchas amplas em faixas, em vez de ruído quadriculado independente.
 float pincel=tinta(floor(repouso*22.0)/22.0);
 float tom=pincel<-.35 ? .98 : (pincel>.38 ? 1.02 : 1.0);
 ALBEDO=cor.rgb*tom;
 ROUGHNESS=1.0;SPECULAR=0.0;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float faixa=n<.12 ? .35 : (n<.60 ? .70 : 1.0);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*faixa/PI;
}
