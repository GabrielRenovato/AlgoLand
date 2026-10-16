shader_type canvas_item;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float cinza = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float grao = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 pedra = mix(vec3(0.30, 0.32, 0.34), vec3(0.82, 0.81, 0.75), cinza);
	COLOR = vec4(pedra * (0.94 + grao * 0.12), base.a);
}
