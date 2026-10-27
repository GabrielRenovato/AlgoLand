shader_type spatial;
render_mode cull_disabled;
uniform vec4 cor_base : source_color = vec4(.75,.78,.82,1.);
uniform vec4 cor_raridade : source_color = vec4(1.);
uniform float tingimento=0.;
uniform vec4 cor_brilho : source_color = vec4(.3,.8,1.,1.);
uniform float intensidade=0.;
uniform bool luz_em_blocos=true;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 ALBEDO=mix(cor_base.rgb,cor_raridade.rgb*max(max(cor_base.r,cor_base.g),cor_base.b),tingimento);
 float faixa=1.-smoothstep(.025,.085,abs(fract(local.y*1.8-TIME*.45)-.5));
 EMISSION=cor_brilho.rgb*intensidade*(.32+faixa*1.8);
 METALLIC=.65;ROUGHNESS=.27;SPECULAR=.65;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float f=n<.08?.35:(n<.58?.70:1.);
 if(!luz_em_blocos)f=mix(.35,1.,smoothstep(0.,.62,n));
 DIFFUSE_LIGHT+=LIGHT_COLOR*f*ATTENUATION/PI;
 float reflexo=pow(max(dot(NORMAL,normalize(LIGHT+VIEW)),0.),24.);
 SPECULAR_LIGHT+=LIGHT_COLOR*reflexo*.65*ATTENUATION;
}
