shader_type canvas_item;
varying vec2 ponto;
varying vec4 tom;
void vertex(){ponto=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;tom=COLOR;}
void fragment(){COLOR=texture(TEXTURE,(mod(floor(ponto),128.0)+0.5)/vec2(128.0,1152.0))*tom;}
