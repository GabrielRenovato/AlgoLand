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
 vec3 p=vec3(UV,UV2.x);
 p=(floor(p/.0125)+.5)*.0125;
 float regiao=UV2.y;
 float eh_metal=1.;
 ALBEDO=metal.rgb;
 if(peca==1){
  if(regiao>.5 && regiao<1.5){
   eh_metal=0.;
   ALBEDO=abs(p.x)<.0125 ? couro_luz.rgb : couro.rgb;
   if(mod(p.y+p.z,.05)<.0125) ALBEDO*=.80;
  }else if(regiao>3.5){
   // Viseira convexa: a superfície e seus furos acompanham a cabeça.
   ALBEDO=metal_luz.rgb;
   if(abs(p.x)<.0125) ALBEDO=mix(metal_luz.rgb,prata.rgb,.45);
   if(p.y>.225 || p.y<.01 || abs(p.x)>.075) ALBEDO=prata.rgb;
   vec2 furo=abs(mod(vec2(p.x+.02,p.y-.025),vec2(.04,.045))-vec2(.02,.0225));
   if(p.y>.035 && p.y<.215 && abs(p.x)<.075 && furo.x<.009 && furo.y<.010) ALBEDO=escuro.rgb;
  }else{
   ALBEDO=metal.rgb;
   if(abs(p.x)<.0125 && p.y>.26) ALBEDO=metal_luz.rgb;
   if(p.z>.07 && abs(p.y-(.255-abs(p.x)*.30))<.0125) ALBEDO=prata.rgb;
   if(abs(p.x)>.11 && p.y<.18) ALBEDO=metal_meio.rgb;
   if(p.y<.0125) ALBEDO=prata.rgb;
  }
 }else if(peca==2){
  if(p.y<altura_grevas && regiao<.5) discard;
  ALBEDO=metal.rgb;
  if(regiao<.5){
   if(p.y<1.10){ALBEDO=couro.rgb;eh_metal=0.;}
   if(p.y>1.49) ALBEDO=prata.rgb;
   if(abs(p.x)>.27 && p.y>1.40) ALBEDO=metal_meio.rgb;
  }else if(regiao>1.5 && regiao<2.5){
   // Arestas inferiores das ombreiras; o centro continua escuro.
   ALBEDO=metal.rgb;
   if(abs(p.x)>.45 || p.y<1.345) ALBEDO=prata.rgb;
   if(p.y>1.58 && abs(p.x)<.33) ALBEDO=metal_luz.rgb;
  }else if(regiao>2.5 && regiao<3.5){
   ALBEDO=metal.rgb;
   if(p.y<.86 || abs(p.x)>.275) ALBEDO=metal_luz.rgb;
  }else if(regiao>3.5 && regiao<4.5){
   ALBEDO=metal.rgb;
   float borda=1.215+abs(p.x)*.472;
   if(abs(p.y-borda)<.025 || p.y>1.47 || abs(p.x)>.188) ALBEDO=prata.rgb;
   if(abs(p.x)<.013 && p.y>1.31 && p.y<1.43) ALBEDO=metal_meio.rgb;
  }else if(regiao>4.5 && regiao<5.5){
   ALBEDO=metal_luz.rgb;
   if(abs(p.x)>.060 || p.y>1.175 || p.y<1.0125) ALBEDO=prata.rgb;
   if(abs(p.y-(1.125-abs(p.x)*.65))<.008) ALBEDO=metal_meio.rgb;
   if(abs(p.x)<.013 && p.y>1.035 && p.y<1.12) ALBEDO=prata.rgb;
  }else if(regiao>5.5){
   ALBEDO=metal.rgb;
   float largura=p.y<.84 ? .125*clamp((p.y-.715)/.125,0.,1.) : .125-(p.y-.84)*.125;
   if(abs(p.x)>largura-.014 || p.y<.75 || p.y>.98) ALBEDO=prata.rgb;
   if(abs(p.x)<.013 && p.y>.78 && p.y<.92) ALBEDO=metal_luz.rgb;
   if(abs(p.y-(.82+abs(p.x)*.6))<.009) ALBEDO=metal_luz.rgb;
  }
 }else if(peca==3){
  ALBEDO=metal_meio.rgb;
  if(regiao>1.5){
   ALBEDO=metal.rgb;
   if(abs(p.x)<.65 || abs(p.x)>.735) ALBEDO=prata.rgb;
   if(mod(abs(p.x)-.65,.042)<.010) ALBEDO=metal_luz.rgb;
  }else if(mod(abs(p.x),.0375)<.0125) ALBEDO=metal_luz.rgb;
 }else{
  ALBEDO=metal.rgb;
  if(regiao>2.5){
   ALBEDO=metal_luz.rgb;
   if(p.y>.575 || p.y<.46) ALBEDO=prata.rgb;
   if(abs(abs(p.x)-.112)<.013) ALBEDO=prata.rgb;
  }else{
   if(p.z>.04 && p.y>.15) ALBEDO=mix(metal_meio.rgb,metal_luz.rgb,.45);
   if(p.y<.035) ALBEDO=escuro.rgb;
   else if(p.y<.065 || p.y>.535) ALBEDO=prata.rgb;
   if(p.z>.085 && p.y<.14) ALBEDO=metal_luz.rgb;
   if(p.y>.19 && mod(p.y-.19,.09)<.014) ALBEDO=metal_luz.rgb;
   if(p.y>.17 && abs(abs(p.x)-.089)>.065) ALBEDO=metal_meio.rgb;
  }
 }
 superficie_metalica=eh_metal;
 METALLIC=eh_metal*.45;
 ROUGHNESS=mix(.95,.28,eh_metal);
 SPECULAR=mix(.0,.65,eh_metal);
}
