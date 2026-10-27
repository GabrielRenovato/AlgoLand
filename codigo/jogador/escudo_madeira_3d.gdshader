shader_type spatial;
render_mode diffuse_burley;
varying vec2 tabua;
void vertex() { tabua=VERTEX.xz; }
void fragment() {
    float indice=floor((tabua.x+0.30)/0.12);
    float faixa=fract((tabua.x+0.30)/0.12);
    float veia=sin(tabua.y*35.0+sin(tabua.y*10.0+indice)*1.5+indice*3.0);
    vec3 madeira=mix(vec3(0.55,0.35,0.235),vec3(0.75,0.54,0.31),0.4+0.17*sin(indice*2.0));
    madeira*=1.0-0.11*smoothstep(0.75,1.0,veia);
    float junta=1.0-smoothstep(0.015,0.055,min(faixa,1.0-faixa));
    ALBEDO=mix(madeira,vec3(0.38,0.25,0.23),junta*0.8);
    ROUGHNESS=1.0;
    SPECULAR=0.0;
}
