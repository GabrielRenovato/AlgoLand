shader_type spatial;
render_mode cull_disabled;
uniform int peca=1;
uniform bool luz_em_blocos=true;
uniform float altura_grevas=0.;
uniform vec4 metal : source_color = vec4(.145,.165,.196,1.);
uniform vec4 metal_meio : source_color = vec4(.208,.263,.306,1.);
uniform vec4 metal_luz : source_color = vec4(.486,.588,.647,1.);
uniform vec4 prata : source_color = vec4(.682,.773,.804,1.);
uniform vec4 escuro : source_color = vec4(.078,.094,.125,1.);
uniform vec4 couro : source_color = vec4(.286,.188,.20,1.);
uniform vec4 couro_luz : source_color = vec4(.42,.275,.255,1.);
void light(){
 float n=dot(NORMAL,LIGHT)*ATTENUATION;
 float f=n<.08 ? .56 : (n<.58 ? .80 : 1.);
 if(!luz_em_blocos) f=mix(.56,1.,smoothstep(0.,.62,n));
 DIFFUSE_LIGHT+=LIGHT_COLOR*f/PI;
}
void fragment(){
 vec3 p=vec3(UV,UV2.x);
 p=(floor(p/.0125)+.5)*.0125;
 float regiao=UV2.y;
 ALBEDO=metal.rgb;
 if(peca==1){
  if(regiao>.5){
   ALBEDO=abs(p.x)<.0125 ? couro_luz.rgb : couro.rgb;
   if(mod(p.y+p.z,.05)<.0125) ALBEDO*=.78;
  }else{
   ALBEDO=metal_meio.rgb;
   float contorno=.18+abs(p.x)*.38;
   if(p.z>.075 && p.y>contorno && p.y<.27) ALBEDO=escuro.rgb;
   if(p.z>.075 && abs(p.y-contorno)<.0125) ALBEDO=prata.rgb;
   if(p.z>.12 && p.y<contorno){
    ALBEDO=abs(p.x)<.025 ? prata.rgb : metal_luz.rgb;
    float x=abs(p.x);
    if(p.y>.035 && p.y<.16 && x<.10 && mod(x+.00625,.0375)<.014 && mod(p.y,.0375)<.015) ALBEDO=escuro.rgb;
   }
   if(abs(p.x)>.115 && p.y<.18) ALBEDO=metal_luz.rgb;
   if(p.y<.0125 || abs(p.y-.275)<.0125) ALBEDO=prata.rgb;
  }
 }else if(peca==2){
  if(p.y<altura_grevas && regiao<.5) discard;
  ALBEDO=metal.rgb;
  if(p.y<1.10 && regiao<.5){
   ALBEDO=couro.rgb;
   if(p.y<.7 && abs(abs(p.x)-.112)<.055 && p.z>.055) ALBEDO=metal_meio.rgb;
  }
  if(p.y>1.1 && abs(p.x)<.27){
   float linha=1.16+abs(p.x)*.30;
   if(abs(p.y-linha)<.018 || p.y>1.49) ALBEDO=prata.rgb;
   if(p.y>linha && p.y<1.47) ALBEDO=metal_meio.rgb;
   if(abs(p.x)<.0125 && p.z>.08) ALBEDO=metal_luz.rgb;
  }
  if(regiao>1.5 && regiao<2.5){
   ALBEDO=metal_meio.rgb;
   if(p.y>1.56 || p.y<1.34) ALBEDO=prata.rgb;
   if(abs(p.x)>.4) ALBEDO=metal_luz.rgb;
  }
  if(regiao>2.5){
   ALBEDO=metal_meio.rgb;
   if(p.y<.86 || abs(abs(p.x)-.25)<.016) ALBEDO=prata.rgb;
   if(abs(p.x)<.06) ALBEDO=metal_luz.rgb;
  }
  if(p.y>1.035 && p.y<1.085) ALBEDO=couro.rgb;
  if(p.z>.1 && abs(p.x)<.035 && p.y>1.025 && p.y<1.095) ALBEDO=prata.rgb;
 }else if(peca==3){
  ALBEDO=metal_meio.rgb;
  if(regiao>1.5 && (abs(p.x)<.67 || abs(p.x)>.735)) ALBEDO=prata.rgb;
  if(regiao<.5 && mod(abs(p.x),.0375)<.0125) ALBEDO=metal_luz.rgb;
 }else{
  ALBEDO=metal_meio.rgb;
  if(p.y<.035) ALBEDO=escuro.rgb;
  else if(p.y<.07 || p.y>.445) ALBEDO=prata.rgb;
  if(p.z>.09 && p.y<.17) ALBEDO=metal_luz.rgb;
  if(p.y>.19 && abs(abs(p.x)-.089)<.025) ALBEDO=metal_luz.rgb;
 }
 ROUGHNESS=.86;SPECULAR=0.;
}
