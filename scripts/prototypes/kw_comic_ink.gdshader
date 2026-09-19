shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink_color : source_color = vec4(0.018, 0.010, 0.022, 1.0);
uniform float width_pixels : hint_range(0.0, 5.0) = 3.5;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_pos = PROJECTION_MATRIX * view_pos;
	vec3 smooth_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 direction = (PROJECTION_MATRIX * vec4(smooth_normal, 0.0)).xy;
	float length_squared = dot(direction, direction);
	if (length_squared > 0.00001 && clip_pos.w > 0.0) {
		direction *= inversesqrt(length_squared);
		clip_pos.xy += direction * (2.0 * width_pixels / VIEWPORT_SIZE) * clip_pos.w;
	}
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
