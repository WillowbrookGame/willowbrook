shader_type spatial;
render_mode cull_disabled;

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform float sock_phase = 0.0;

void vertex() {
	// The attachment stays still; the solid pole and cap are inside |x| <= 0.135.
	float reach = smoothstep(0.15, 1.58, VERTEX.x);
	float wave = sin(sock_phase - VERTEX.x * 3.5);
	VERTEX.y += reach * (wave * 0.13 + sin(sock_phase * 1.7) * 0.04);
	VERTEX.z += reach * sin(sock_phase * 0.83 - VERTEX.x * 2.0) * 0.14;
}

void fragment() {
	ALBEDO = texture(palette, UV).rgb;
	ROUGHNESS = 0.9;
}
