shader_type spatial;
render_mode diffuse_burley;
// Material próprio: a tinta não depende das regiões de pele ou tecido.
uniform sampler2D textura_cabelo : source_color, filter_nearest;
uniform sampler2D desenho_cabelo : source_color, filter_nearest;
uniform bool desenho_pixel_cabeca = true;
uniform bool usar_cor_pintada = true;
uniform bool recortar_cartola = false;
uniform vec4 cor_cabelo : source_color = vec4(1.0);
void fragment() {
    if (recortar_cartola && UV2.y > .235) discard;
    vec3 pintura = desenho_pixel_cabeca ? texture(desenho_cabelo, UV).rgb : texture(textura_cabelo, UV).rgb;
    float luminosidade = dot(pintura, vec3(.299, .587, .114));
    ALBEDO = usar_cor_pintada ? pintura : clamp(cor_cabelo.rgb * luminosidade * 2.1, 0.0, 1.0);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
