shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 zone_center_world = vec2(1024.0, 1024.0);
uniform float zone_radius = 1320.0;
uniform vec2 camera_center_world = vec2(1024.0, 1024.0);
uniform vec2 camera_zoom = vec2(1.0, 1.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float edge_feather_world = 44.0;
uniform float outside_opacity = 0.38;
uniform float edge_glow_opacity = 0.34;
uniform float distortion_strength = 0.0052;
uniform vec4 outside_tint = vec4(1.0, 0.16, 0.1, 1.0);
uniform float time_sec = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	vec2 world_pos = camera_center_world + centered_uv * viewport_size * camera_zoom;
	float dist_world = distance(world_pos, zone_center_world);

	float outside = smoothstep(zone_radius - edge_feather_world, zone_radius + edge_feather_world, dist_world);
	float edge = smoothstep(zone_radius - edge_feather_world * 1.15, zone_radius, dist_world)
		* (1.0 - smoothstep(zone_radius, zone_radius + edge_feather_world * 1.9, dist_world));

	vec2 n_uv = world_pos * 0.0036 + vec2(time_sec * 0.14, -time_sec * 0.09);
	float n = noise21(n_uv);
	float fire = smoothstep(0.44, 0.92, n);

	vec2 distort_dir = vec2(
		sin(time_sec * 1.7 + world_pos.y * 0.006 + n * 6.28318),
		cos(time_sec * 1.3 + world_pos.x * 0.006 - n * 6.28318)
	);
	vec2 distort_uv = SCREEN_UV + distort_dir * (distortion_strength * outside);

	vec3 shifted_scene = texture(screen_texture, clamp(distort_uv, vec2(0.0), vec2(1.0))).rgb;
	vec3 outside_mix = mix(shifted_scene, shifted_scene * 0.53 + outside_tint.rgb * 0.74, outside * 0.95);
	vec3 edge_fire = outside_tint.rgb * edge * (0.45 + 0.85 * fire) * edge_glow_opacity;

	float alpha = outside * outside_opacity + edge * edge_glow_opacity * (0.55 + 0.45 * fire);
	COLOR = vec4(outside_mix + edge_fire, clamp(alpha, 0.0, 0.74));
}
