shader_type spatial;
render_mode cull_disabled;
uniform int traje=0;
uniform int peca=0;
uniform vec4 tecido : source_color=vec4(.46,.59,.39,1.);
uniform vec4 detalhe : source_color=vec4(.87,.79,.59,1.);
uniform vec4 cor_cabelo : source_color=vec4(.28,.16,.10,1.);
uniform bool luz_em_blocos=true;
void light(){
 float n=dot(NORMAL,LIGHT);
 float f=luz_em_blocos ? (n<.10 ? .56 : (n<.58 ? .82 : 1.0)) : mix(.56,1.0,smoothstep(0.,.65,n));
 DIFFUSE_LIGHT+=LIGHT_COLOR*f*ATTENUATION/PI;
}
void fragment(){
 vec3 p=vec3(UV,UV2.x);
 p=(floor(p/.015)+.5)*.015;
 float regiao=UV2.y;
 vec3 cor=tecido.rgb;
 if(peca==3){
  cor=cor_cabelo.rgb;
  float mecha=mod(p.x*1.6+p.z,.06);
  if(mecha<.015 && p.y>.18)cor*=1.13;
  if(p.y<.09)cor*=.80;
  // Elásticos presos às duas caudas, sem pintar o rosto.
  if(regiao>3.5)cor=detalhe.rgb;
 }else if(peca==0){
  if(p.y>1.45 || p.y<1.055)cor=detalhe.rgb;
  if(abs(p.x)>.39)cor=detalhe.rgb;
  if(traje==0){
   if(p.y>1.23 && p.y<1.29)cor=detalhe.rgb;
   if(p.z>.12 && abs(p.x)<.025 && p.y>1.31)cor*=.69;
  }else if(traje==1){
   if(p.y>1.36 && p.y<1.40)cor*=.82;
  }else{
   if(abs(p.x)<.026 && p.z>.13 && p.y>1.25 && mod(p.y,.10)<.018)cor=detalhe.rgb;
   if(p.y<1.11)cor*=.82;
  }
 }else{
  if(traje<2){
   if(p.y<.69)cor=detalhe.rgb;
   if(abs(p.z)<.10 && mod(abs(p.x),.13)<.015)cor*=.78;
   if(traje==0 && p.y>.73 && p.y<.86 && abs(p.x)>.17)cor*=.78;
   if(traje==1 && regiao>1.5){
    cor=tecido.rgb;
    if(p.y>1.29 && p.y<1.32)cor=detalhe.rgb;
    if(p.y>1.22 && p.y<1.31 && abs(p.x)<.065 && p.z>.16){
     if(p.y<1.235 || abs(p.x)>.05)cor*=.74;
    }
    if(p.y>1.35 && abs(abs(p.x)-.10)<.025 && p.z>.08)cor=vec3(.83,.64,.30);
   }
  }else{
   if(p.y<.73)cor=detalhe.rgb;
   if(mod(abs(p.x),.09)<.016 && p.y<.93)cor*=.87;
   if(p.z>.18 && abs(p.x)<.08 && p.y>.80 && p.y<.92)cor=detalhe.rgb;
  }
 }
 ALBEDO=cor;
 ROUGHNESS=.96;
 SPECULAR=0.;
}
