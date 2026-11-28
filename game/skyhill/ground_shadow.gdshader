shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float opacity = 0.0;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.09, 0.13, 0.10);
	ALPHA = opacity * (1.0 - smoothstep(0.16, 1.0, radius));
}
