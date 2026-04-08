shader_type canvas_item;
render_mode blend_mix;

uniform float walk_strength : hint_range(0.0, 1.0) = 0.0;
uniform float air_factor : hint_range(0.0, 1.0) = 0.0;
uniform float facing_sign : hint_range(-1.0, 1.0) = 1.0;
uniform float white_threshold : hint_range(0.9, 1.0) = 0.995;

float hair_mask_at(vec2 uv) {
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * COLOR;
	if (c.a <= 0.01) {
		return 0.0;
	}

	float min_rgb = min(c.r, min(c.g, c.b));
	float max_rgb = max(c.r, max(c.g, c.b));
	float spread = max_rgb - min_rgb;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));

	// Pure white hair pixels.
	float pure_white = step(white_threshold, min_rgb);

	// Very light/cool tones used by Gan hair highlights (e.g. #ccf2f4 / #b0d1d3).
	float light_band = step(0.68, c.r) * step(0.74, c.g) * step(0.78, c.b);
	float cool_order = step(c.r - 0.03, c.g) * step(c.g - 0.08, c.b);
	float low_saturation = 1.0 - step(0.26, spread);
	float bright_enough = step(0.70, luma);
	float icy_hair = light_band * cool_order * low_saturation * bright_enough;

	return max(pure_white, icy_hair);
}

float expanded_hair_mask(vec2 uv, vec2 texel) {
	float m = hair_mask_at(uv);
	m = max(m, hair_mask_at(uv + vec2(texel.x, 0.0)));
	m = max(m, hair_mask_at(uv + vec2(-texel.x, 0.0)));
	m = max(m, hair_mask_at(uv + vec2(0.0, texel.y)));
	m = max(m, hair_mask_at(uv + vec2(0.0, -texel.y)));
	m = max(m, hair_mask_at(uv + vec2(texel.x, texel.y)));
	m = max(m, hair_mask_at(uv + vec2(-texel.x, texel.y)));
	m = max(m, hair_mask_at(uv + vec2(texel.x, -texel.y)));
	m = max(m, hair_mask_at(uv + vec2(-texel.x, -texel.y)));
	return m;
}

float expanded_hair_mask_wide(vec2 uv, vec2 texel) {
	float m = expanded_hair_mask(uv, texel);
	m = max(m, expanded_hair_mask(uv + vec2(texel.x * 2.0, 0.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(-texel.x * 2.0, 0.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(0.0, texel.y * 2.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(0.0, -texel.y * 2.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(texel.x * 3.0, 0.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(-texel.x * 3.0, 0.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(0.0, texel.y * 3.0), texel));
	m = max(m, expanded_hair_mask(uv + vec2(0.0, -texel.y * 3.0), texel));
	return m;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float hair_mask = hair_mask_at(UV);
	float hair_mask_expanded = expanded_hair_mask(UV, texel);

	float motion = clamp(walk_strength * 1.25 + air_factor * 1.5, 0.0, 1.0);
	if (motion <= 0.001 || hair_mask_expanded <= 0.0) {
		COLOR = base;
		return;
	}
	float boosted_motion = max(motion, 0.35);

	float sway_a = sin(TIME * 18.0 + UV.y * 96.0);
	float sway_b = sin(TIME * 11.5 + UV.y * 54.0 + UV.x * 31.0);
	float sway_c = sin(TIME * 15.2 + UV.x * 78.0);
	float pixel_shift_x = round((sway_a * 1.55 + sway_b * 1.25) * boosted_motion * 3.3 * facing_sign);
	pixel_shift_x = clamp(pixel_shift_x, -5.0, 5.0);
	float pixel_shift_y = round(sway_c * 1.25 * boosted_motion);
	pixel_shift_y = clamp(pixel_shift_y, -3.0, 3.0);
	vec2 shifted_uv = clamp(UV - vec2(pixel_shift_x, pixel_shift_y) * texel, vec2(0.0), vec2(1.0));
	vec4 shifted = texture(TEXTURE, shifted_uv) * COLOR;
	float shifted_hair_mask = expanded_hair_mask_wide(shifted_uv, texel);
	float blend_strength = clamp(0.55 + boosted_motion * 0.45, 0.0, 1.0);

	vec4 windy = shifted;
	windy.rgb = mix(windy.rgb, vec3(1.0), 0.62);
	float fringe_mask = expanded_hair_mask_wide(UV, texel) * shifted_hair_mask;
	float paint_mask = max(hair_mask, hair_mask_expanded * 0.96) * shifted_hair_mask;
	float final_mask = max(paint_mask, fringe_mask * 0.72);
	COLOR = mix(base, windy, final_mask * blend_strength);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), final_mask * 0.16);
	COLOR.a = max(base.a, final_mask * 0.98);
}
