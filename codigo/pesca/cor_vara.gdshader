shader_type canvas_item;
uniform vec4 cor_nivel : source_color = vec4(1.0);
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float luz = max(base.r,max(base.g,base.b));
    COLOR = vec4(mix(base.rgb,cor_nivel.rgb*luz,0.85),base.a);
}
