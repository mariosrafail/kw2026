shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink_color : source_color = vec4(0.018, 0.010, 0.022, 1.0);
uniform float width_pixels : hint_range(0.0, 5.0) = 3.5;
uniform int damage_cell_count = 0;
uniform vec4 damage_cells[32];
varying vec3 damage_local_position;

void vertex() {
	damage_local_position = VERTEX;
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
	for (int i = 0; i < 32; i++) {
		if (i >= damage_cell_count) { break; }
		vec3 d = abs(damage_local_position - damage_cells[i].xyz);
		if (all(lessThan(d, vec3(damage_cells[i].w)))) { discard; }
	}
	ALBEDO = ink_color.rgb;
}
