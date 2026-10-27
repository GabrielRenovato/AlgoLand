shader_type spatial;
render_mode cull_disabled;
uniform int peca = 1;
uniform float altura_grevas = 0.;
uniform bool luz_em_blocos = true;
uniform vec4 tecido : source_color = vec4(0.224,0.224,0.310,1.0);
uniform vec4 sombra : source_color = vec4(0.082,0.082,0.122,1.0);
uniform vec4 lapela : source_color = vec4(0.325,0.325,0.416,1.0);
uniform vec4 camisa : source_color = vec4(0.949,0.894,0.808,1.0);
uniform vec4 couro : source_color = vec4(0.553,0.294,0.173,1.0);
uniform vec4 couro_luz : source_color = vec4(0.741,0.478,0.251,1.0);
uniform vec4 ouro : source_color = vec4(0.863,0.718,0.373,1.0);
uniform vec4 vinho : source_color = vec4(0.663,0.169,0.275,1.0);
void light() {
 float n=dot(NORMAL,LIGHT)*ATTENUATION;
 float f=n<0.08 ? 0.56 : (n<0.58 ? 0.80 : 1.0);
 if (!luz_em_blocos) f=mix(.56,1.,smoothstep(0.,.62,n));
 DIFFUSE_LIGHT+=LIGHT_COLOR*f/PI;
}
void fragment() {
 vec3 p=vec3(UV,UV2.x);
 p=(floor(p/.0125)+.5)*.0125;
 ALBEDO=tecido.rgb;
 if (peca==1) {
  if(p.y<.255) ALBEDO=lapela.rgb;
  if(p.y>=.255 && p.y<.30) ALBEDO=vinho.rgb;
  if(p.y>.43) ALBEDO=lapela.rgb;
 } else if (peca==2) {
  if(p.y<altura_grevas) discard;
  if (p.y<1.025) {
   ALBEDO=tecido.rgb*.86;
   if(abs(abs(p.x)-.155)<.0125) ALBEDO=lapela.rgb*.82;
   if(p.y>.975) ALBEDO=sombra.rgb;
  } else if(abs(p.x)>.27) {
   if(abs(p.x)>.69) ALBEDO=camisa.rgb;
   if(abs(p.x)>.66 && abs(p.x)<.69 && p.z>-.02) ALBEDO=ouro.rgb;
  } else if (p.z>.055) {
   float abertura=mix(.145,.074,clamp((p.y-1.04)/.44,0.,1.));
   if(abs(p.x)<abertura) ALBEDO=couro.rgb;
   if(abs(abs(p.x)-abertura)<.022 && p.y>1.16) ALBEDO=lapela.rgb;
   float gola=clamp((p.y-1.32)/.17,0.,1.)*.092;
   if(p.y>1.32 && abs(p.x)<gola) ALBEDO=camisa.rgb;
   if(abs(p.x)<.019 && p.y>1.32 && p.y<1.47) ALBEDO=vinho.rgb;
   if(abs(p.x)<.013 && p.y>1.07 && p.y<1.32 && mod(p.y-1.08,.075)<.022) ALBEDO=ouro.rgb;
  } else {
   if(abs(p.x)<.01) ALBEDO=sombra.rgb;
   if(abs(abs(p.x)-.065)<.015 && abs(p.y-1.065)<.015) ALBEDO=ouro.rgb;
  }
  if(UV2.y>.5) ALBEDO=tecido.rgb*1.06;
 } else if (peca==3) {
  ALBEDO=camisa.rgb;
  if(abs(p.x)<.741) ALBEDO=lapela.rgb;
 } else {
  ALBEDO=couro.rgb;
  if(p.y<.035) ALBEDO=sombra.rgb;
  else if(p.y<.065 || (p.z>.085 && p.y<.13)) ALBEDO=couro_luz.rgb;
  if(p.y>.24) ALBEDO=couro.rgb*.72;
 }
 ROUGHNESS=1.;SPECULAR=0.;
}
