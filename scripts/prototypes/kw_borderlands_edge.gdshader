shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;

// Godot 4 adaptation of the supplied NekotoArts Borderlands-style edge detector.
// Source: https://godotshaders.com/shader/3d-edge-detection-shader-borderlands-style/ (CC0 code).
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 edge_color : source_color = vec4(0.012, 0.008, 0.016, 1.0);
uniform float thickness_px : hint_range(0.5, 3.0, 0.05) = 1.15;
uniform float color_threshold : hint_range(0.0, 0.5, 0.005) = 0.055;
uniform float color_blend : hint_range(0.001, 0.5, 0.005) = 0.095;
uniform float depth_threshold : hint_range(0.0, 0.25, 0.002) = 0.012;
uniform float depth_blend : hint_range(0.001, 0.5, 0.002) = 0.040;
uniform float edge_strength : hint_range(0.0, 1.0, 0.01) = 0.94;
uniform float distance_fade_start : hint_range(0.0, 100.0, 1.0) = 24.0;
uniform float distance_fade_end : hint_range(1.0, 160.0, 1.0) = 58.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
float grayscale(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float linear_depth_at(vec2 uv, mat4 inv_projection) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	view.xyz /= max(abs(view.w), 0.000001);
	return max(0.0, -view.z);
}

void fragment() {
	vec2 pixel = (1.0 / VIEWPORT_SIZE) * thickness_px;
	vec2 uv = SCREEN_UV;
	vec3 center_color = textureLod(screen_texture, uv, 0.0).rgb;
float left_color = grayscale(textureLod(screen_texture, uv - vec2(pixel.x, 0.0), 0.0).rgb);
	float right_color = grayscale(textureLod(screen_texture, uv + vec2(pixel.x, 0.0), 0.0).rgb);
	float up_color = grayscale(textureLod(screen_texture, uv - vec2(0.0, pixel.y), 0.0).rgb);
	float down_color = grayscale(textureLod(screen_texture, uv + vec2(0.0, pixel.y), 0.0).rgb);
	float color_gradient = max(abs(right_color - left_color), abs(down_color - up_color));
	float color_edge = smoothstep(color_threshold, color_threshold + color_blend, color_gradient);

	float center_depth = linear_depth_at(uv, INV_PROJECTION_MATRIX);
	float left_depth = linear_depth_at(uv - vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX);
	float right_depth = linear_depth_at(uv + vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX);
	float up_depth = linear_depth_at(uv - vec2(0.0, pixel.y), INV_PROJECTION_MATRIX);
	float down_depth = linear_depth_at(uv + vec2(0.0, pixel.y), INV_PROJECTION_MATRIX);
float depth_scale = max(center_depth, 0.5);
	float depth_gradient = max(abs(right_depth - left_depth), abs(down_depth - up_depth)) / depth_scale;
	float depth_edge = smoothstep(depth_threshold, depth_threshold + depth_blend, depth_gradient);

	float distance_fade = 1.0 - smoothstep(distance_fade_start, distance_fade_end, center_depth);
	float edge = clamp(max(color_edge, depth_edge) * distance_fade * edge_strength, 0.0, 1.0);
	ALBEDO = mix(center_color, edge_color.rgb, edge);
}
