shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.95, 0.76, 0.2, 0.95);
uniform vec4 bg_color : source_color = vec4(0.06, 0.08, 0.12, 0.85);
uniform float inner_radius : hint_range(0.0, 0.95) = 0.52;
uniform float outer_radius : hint_range(0.05, 1.0) = 0.95;
uniform float start_angle_deg : hint_range(0.0, 360.0) = 270.0;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0);
	float dist = length(uv);
	if (dist < inner_radius || dist > outer_radius) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		float angle = degrees(atan(uv.y, uv.x));
		if (angle < 0.0) {
			angle += 360.0;
		}

		float start = start_angle_deg;
		float clockwise_delta = mod(start - angle + 360.0, 360.0);
		float filled_angle = clamp(progress, 0.0, 1.0) * 360.0;
		vec4 color = bg_color;
		if (clockwise_delta <= filled_angle) {
			color = fill_color;
		}

		COLOR = color;
	}
}
