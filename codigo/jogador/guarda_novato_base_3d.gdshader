shader_type spatial;
render_mode cull_disabled;
uniform int peca=1;
uniform bool luz_em_blocos=true;
uniform float altura_grevas=0.;
uniform vec4 metal : source_color=vec4(.25,.30,.34,1.);
uniform vec4 metal_meio : source_color=vec4(.35,.42,.46,1.);
uniform vec4 metal_luz : source_color=vec4(.58,.67,.71,1.);
uniform vec4 prata : source_color=vec4(.78,.83,.82,1.);
uniform vec4 escuro : source_color=vec4(.07,.10,.13,1.);
uniform vec4 couro : source_color=vec4(.23,.16,.12,1.);
uniform vec4 couro_luz : source_color=vec4(.40,.28,.19,1.);
varying float superficie_metalica;
void light(){
 float n=dot(NORMAL,LIGHT);
 float f=luz_em_blocos ? (n<.08 ? .38 : (n<.58 ? .72 : 1.)) : mix(.38,1.,smoothstep(0.,.65,n));
 DIFFUSE_LIGHT+=LIGHT_COLOR*f*ATTENUATION/PI;
 float reflexo=pow(max(dot(NORMAL,normalize(LIGHT+VIEW)),0.),24.);
 if(luz_em_blocos)reflexo=reflexo>.48 ? .65 : (reflexo>.15 ? .18 : 0.);
 SPECULAR_LIGHT+=LIGHT_COLOR*vec3(.82,.91,1.)*reflexo*ATTENUATION*superficie_metalica;
}
void fragment(){
 vec3 p=(floor(vec3(UV,UV2.x)/.0125)+.5)*.0125;
 float r=UV2.y;
 float metalico=1.;
 ALBEDO=metal.rgb;
 if(peca==1){
  // Janela real na calota: deixa o rosto canônico aparecer entre as abas laterais.
  float topo_abertura=.225-abs(p.x)*.20;
  if(r<.5 && p.z>.045 && abs(p.x)<.095 && p.y>-.075 && p.y<topo_abertura)discard;
  if(r>.5 && r<1.5){
   ALBEDO=metal_luz.rgb;
   if(p.y>.43)ALBEDO=prata.rgb;
  }else{
   if(p.y>.30 || p.y<.0)ALBEDO=metal_luz.rgb;
   if(p.y>.225 && p.y<.25)ALBEDO=prata.rgb;
  }
 }else if(peca==2){
  if(r<.5){
   if(p.y<altura_grevas)discard;
   ALBEDO=metal_meio.rgb;
   if(p.y<1.10){ALBEDO=escuro.rgb;metalico=0.;}
   if(abs(p.x)>.42 && mod(abs(p.x)-.42,.065)<.014)ALBEDO=prata.rgb;
  }else if(r>1.5 && r<2.5){
   ALBEDO=metal_meio.rgb;
   if(p.y>1.575 || p.y<1.35 || abs(p.x)>.45)ALBEDO=metal_luz.rgb;
   if(abs(p.x)>.40 && abs(p.x)<.425)ALBEDO=prata.rgb;
  }else if(r>2.5 && r<3.5){
   ALBEDO=metal_meio.rgb;
   if(mod(1.055-p.y,.074)>.059)ALBEDO=prata.rgb;
   if(p.y>1.015){ALBEDO=couro.rgb;metalico=0.;}
   if(p.z>.17 && abs(p.x)<.04 && p.y>1.015){ALBEDO=prata.rgb;metalico=1.;}
  }else if(r>3.5 && r<4.5){
   float costura=.035+(p.y-1.04)*.32;
   if(abs(abs(p.x)-costura)<.014)ALBEDO=metal_luz.rgb;
   if(abs(p.x)<.0125)ALBEDO=metal_meio.rgb;
   if(abs(abs(p.x)-costura)<.018 && abs(mod(p.y-1.10,.0875)-.04375)<.0125)ALBEDO=prata.rgb;
   if(p.y>1.45 || p.y<1.05)ALBEDO=metal_luz.rgb;
  }else{
   ALBEDO=metal_meio.rgb;
   if(p.y>1.565 || p.y<1.465)ALBEDO=prata.rgb;
  }
 }else if(peca==3){
  ALBEDO=metal_meio.rgb;
  if(r>1.5){
   if(abs(p.x)<.60 || abs(p.x)>.725)ALBEDO=prata.rgb;
   else if(mod(abs(p.x),.0625)<.014)ALBEDO=metal_luz.rgb;
  }else if(mod(abs(p.x),.0375)<.0125)ALBEDO=metal_luz.rgb;
 }else{
  ALBEDO=metal_meio.rgb;
  if(r>2.5){
   ALBEDO=metal_luz.rgb;
   if(abs(abs(p.x)-.112)<.013)ALBEDO=prata.rgb;
   if(p.y<.465 || p.y>.575)ALBEDO=metal.rgb;
  }else{
   if(p.y<.035)ALBEDO=escuro.rgb;
   else if(p.y<.065 || p.z>.085 && p.y<.14)ALBEDO=prata.rgb;
   if(p.y>.19 && abs(abs(p.x)-.089)<.0125)ALBEDO=metal_luz.rgb;
   if(p.y>.15 && mod(p.y-.15,.0875)<.0125)ALBEDO=metal.rgb;
  }
 }
 superficie_metalica=metalico;
 METALLIC=metalico*.5;
 ROUGHNESS=mix(.95,.32,metalico);
 SPECULAR=.55*metalico;
}
