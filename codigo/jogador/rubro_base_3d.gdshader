shader_type spatial;
render_mode cull_disabled;
uniform int peca=1;
uniform bool luz_em_blocos=true;
uniform float altura_grevas=0.;
uniform vec4 metal : source_color = vec4(.090,.118,.133,1.);
uniform vec4 metal_meio : source_color = vec4(.149,.196,.220,1.);
uniform vec4 metal_luz : source_color = vec4(.451,.545,.561,1.);
uniform vec4 prata : source_color = vec4(.706,.769,.769,1.);
uniform vec4 escuro : source_color = vec4(.063,.086,.098,1.);
uniform vec4 couro : source_color = vec4(.188,.145,.161,1.);
uniform vec4 couro_luz : source_color = vec4(.286,.200,.212,1.);
uniform vec4 bronze : source_color = vec4(.57,.43,.26,1.);
varying float superficie_metalica;
void light(){
 float n=dot(NORMAL,LIGHT);
 float f=n<.08 ? .56 : (n<.58 ? .80 : 1.);
 if(!luz_em_blocos) f=mix(.56,1.,smoothstep(0.,.62,n));
 float contraste=n<.08 ? .22 : (n<.58 ? .57 : 1.0);
 DIFFUSE_LIGHT+=LIGHT_COLOR*mix(f,contraste,superficie_metalica)*ATTENUATION/PI;
 // Reflexo estreito do sol e uma faixa fria do ambiente: só nas placas.
 vec3 meio=normalize(LIGHT+VIEW);
 float solar=pow(max(dot(NORMAL,meio),0.),28.);
 float faixa=1.-smoothstep(.045,.16,abs(reflect(-VIEW,NORMAL).y+.30));
 if(luz_em_blocos){
  solar=solar>.68 ? 1. : (solar>.20 ? .34 : 0.);
  faixa=faixa>.72 ? 1. : (faixa>.34 ? .30 : 0.);
 }
 float brilho=solar*.75*step(.03,n)+faixa*.11;
 SPECULAR_LIGHT+=LIGHT_COLOR*vec3(.82,.93,.95)*brilho*ATTENUATION*superficie_metalica;
}
void fragment(){
 vec3 p=(floor(vec3(UV,UV2.x)/.0125)+.5)*.0125;
 float regiao=UV2.y;
 float eh_metal=1.;
 ALBEDO=metal.rgb;
 if(peca==1){
  if(regiao>.5 && regiao<1.5){
   // Chifres de metal com nervuras de bronze, sem brilho no fundo do visor.
   ALBEDO=metal_meio.rgb;
   if(mod(p.y+p.x*.35,.0375)<.0125) ALBEDO=bronze.rgb;
  }else if(regiao>3.5){
   ALBEDO=metal_meio.rgb;
   if(abs(p.x)<.013) ALBEDO=bronze.rgb;
   if(p.y>.225 || p.y<.0 || abs(p.x)>.080) ALBEDO=bronze.rgb;
   float olho=.175-abs(p.x)*.24;
   if(abs(p.y-olho)<.014 && abs(p.x)>.013){ALBEDO=escuro.rgb;eh_metal=0.;}
   if(p.y<.14 && abs(p.x)>.025 && abs(p.x)<.065 && mod(p.x+.005,.0375)<.0125) ALBEDO=escuro.rgb;
  }else{
   if(p.y<.0 || (p.z>.065 && abs(p.y-(.25-abs(p.x)*.18))<.013)) ALBEDO=bronze.rgb;
   if(mod(p.x,.05)<.008 && p.y>.23) ALBEDO=metal_luz.rgb;
  }
 }else if(peca==2){
  if(regiao<.5){
   if(p.y<altura_grevas) discard;
   ALBEDO=metal.rgb;
   if(p.y<1.08){ALBEDO=escuro.rgb;eh_metal=0.;}
   else if(abs(p.x)>.27){
    if(mod(abs(p.x),.065)<.0125) ALBEDO=metal_luz.rgb;
    if(abs(p.x)<.46 && p.y<1.38){ALBEDO=couro_luz.rgb;eh_metal=0.;}
   }
   if(p.y>1.48) ALBEDO=bronze.rgb;
   if(p.z<-.10 && abs(p.x)<.014 && p.y>1.12) ALBEDO=bronze.rgb;
  }else if(regiao>1.5 && regiao<2.5){
   ALBEDO=metal_meio.rgb;
   float camada=floor((regiao-2.)*10.+.5);
   float x=abs(p.x)-(.225+camada*.067);
   if(x>.105 || x<.035) ALBEDO=bronze.rgb;
   if(mod(p.z+.025,.0625)<.0125) ALBEDO=metal_luz.rgb;
  }else if(regiao>2.5 && regiao<3.5){
   eh_metal=0.;
   ALBEDO=mix(couro.rgb,couro_luz.rgb,step(.02,mod(abs(p.x)*2.+p.z,.0875))*.65);
   // Galão e arabescos largos, legíveis na grade nativa.
   if(p.y<.735 || abs(p.x)>.27 || mod(atan(p.z,p.x)+.095,1.5708)<.12) ALBEDO=bronze.rgb;
   vec2 ornamento=abs(mod(vec2(p.x+p.z,p.y-.76),vec2(.10,.12))-vec2(.05,.06));
   if(p.y<.88 && abs(ornamento.x+ornamento.y-.0375)<.009) ALBEDO=bronze.rgb;
  }else if(regiao>3.5 && regiao<4.5){
   ALBEDO=metal_meio.rgb;
   float v=1.14+abs(p.x)*.56;
   if(abs(p.y-v)<.018 || p.y>1.465 || abs(p.x)>.18) ALBEDO=bronze.rgb;
   if(abs(p.x)<.013) ALBEDO=metal_luz.rgb;
   // Brasão central abstrato gravado, sem ruído de detalhes subpixel.
   if(p.y>1.30 && p.y<1.43 && abs(p.x)<.085){
    if(abs(abs(p.x)-abs(p.y-1.36)*.9)<.013 || abs(p.y-1.365)<.010) ALBEDO=bronze.rgb;
   }
  }else if(regiao>4.5 && regiao<5.5){
   ALBEDO=metal.rgb;
   if(p.y>1.105 || p.y<1.025) ALBEDO=bronze.rgb;
   if(mod(atan(p.z,p.x)+.06,.31)<.07 && p.y<1.10 && p.y>1.035) ALBEDO=prata.rgb;
  }else if(regiao>5.5 && regiao<6.5){
   ALBEDO=metal_meio.rgb;
   if(abs(p.x)<.013 || p.y<.81 || p.y>1.015 || abs(p.x)>.073) ALBEDO=bronze.rgb;
  }else{
   ALBEDO=metal_meio.rgb;
   if(mod(p.y,.0375)<.0125) ALBEDO=bronze.rgb;
  }
 }else if(peca==3){
  ALBEDO=metal_meio.rgb;
  if(regiao>1.5){
   ALBEDO=metal.rgb;
   if(abs(p.x)<.65 || abs(p.x)>.735) ALBEDO=bronze.rgb;
   if(mod(abs(p.x)-.65,.042)<.010) ALBEDO=metal_luz.rgb;
  }else if(mod(abs(p.x),.0375)<.0125) ALBEDO=metal_luz.rgb;
 }else{
  ALBEDO=metal_meio.rgb;
  if(regiao>2.5){
   if(p.y>.575 || p.y<.46 || abs(abs(p.x)-.112)<.013) ALBEDO=bronze.rgb;
  }else{
   if(p.y<.035) ALBEDO=escuro.rgb;
   else if(p.y<.065 || p.y>.535) ALBEDO=bronze.rgb;
   if(p.z>.085 && p.y<.14) ALBEDO=metal_luz.rgb;
   if(p.y>.19 && mod(p.y-.19,.065)<.014) ALBEDO=prata.rgb;
   if(p.y>.17 && abs(abs(p.x)-.089)>.065) ALBEDO=metal.rgb;
  }
 }
 superficie_metalica=eh_metal;
 METALLIC=eh_metal*.50;
 ROUGHNESS=mix(.96,.30,eh_metal);
 SPECULAR=mix(0.,.65,eh_metal);
}
