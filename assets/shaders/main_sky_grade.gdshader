shader_type canvas_item;

uniform float time_sec = 0.0;
uniform vec4 deep_tint : source_color = vec4(0.17, 0.57, 0.93, 1.0);
uniform vec4 warm_tint : source_color = vec4(0.99, 0.73, 0.32, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float horizon = smoothstep(0.18, 0.92, UV.y);
	float shimmer = 0.03 * sin(UV.x * 16.0 + time_sec * 0.35) + 0.02 * cos(UV.y * 12.0 - time_sec * 0.2);
	vec3 graded = tex.rgb * mix(deep_tint.rgb, warm_tint.rgb, horizon * 0.35 + shimmer);
	graded += vec3(0.05, 0.08, 0.12) * (0.15 + 0.1 * sin(time_sec * 0.4 + UV.y * 4.0));
	COLOR = vec4(graded, tex.a);
}
