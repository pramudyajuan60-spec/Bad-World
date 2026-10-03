shader_type canvas_item;

// Fog of war: darkens areas far from friendly units.
// vision_points: array of unit positions (in screen/world space via SCREEN_UV transform).
// Simplified: uses distance from screen center of revealed circles passed as uniforms.

uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 0.75);
uniform vec2 unit_positions[32];
uniform int unit_count = 0;
uniform float vision_radius = 300.0;

void fragment() {
	vec2 uv = UV;
	vec2 aspect = vec2(1.0, 0.5625); // 16:9 approx; refined by game code if needed
	float min_dist = 1e9;
	for (int i = 0; i < 32; i++) {
		if (i >= unit_count) { break; }
		float d = distance(uv, unit_positions[i]);
		min_dist = min(min_dist, d);
	}
	float reveal = smoothstep(vision_radius * 0.7, vision_radius, min_dist);
	COLOR = vec4(fog_color.rgb, fog_color.a * reveal);
}
