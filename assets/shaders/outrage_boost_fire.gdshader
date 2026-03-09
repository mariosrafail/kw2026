shader_type canvas_item;
render_mode unshaded;

uniform float fire_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 hot_color : source_color = vec4(1.0, 0.94, 0.24, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.34, 0.08, 1.0);
uniform vec4 low_color : source_color = vec4(0.72, 0.04, 0.0, 1.0);
uniform float flicker_speed : hint_range(1.0, 24.0) = 11.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 pixel_uv = UV / TEXTURE_PIXEL_SIZE;
		vec2 pixel_cell = floor(pixel_uv);
		float time_step = floor(TIME * flicker_speed);
		float vertical_bias = 1.0 - clamp(UV.y, 0.0, 1.0);
		float coarse_noise = hash(floor(pixel_cell * 0.6) + vec2(time_step * 0.8, floor(time_step * 0.37)));
		float fine_noise = hash(pixel_cell + vec2(time_step, floor(time_step * 0.61)));
		float neighbor_noise = hash(pixel_cell.yx * vec2(0.73, 1.19) + vec2(floor(time_step * 0.5), time_step * 0.25));
		float flame_mask = clamp(
			0.18 + vertical_bias * 0.46 + coarse_noise * 0.34 + fine_noise * 0.26 + neighbor_noise * 0.18,
			0.0,
			1.0
		);

		vec3 fire_rgb = mix(low_color.rgb, mid_color.rgb, smoothstep(0.18, 0.62, flame_mask));
		fire_rgb = mix(fire_rgb, hot_color.rgb, smoothstep(0.58, 0.97, flame_mask));

		COLOR = vec4(mix(tex.rgb, fire_rgb, fire_strength), tex.a);
	}
}
