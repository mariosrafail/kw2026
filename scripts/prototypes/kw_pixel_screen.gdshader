shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform float target_height : hint_range(180.0, 720.0) = 360.0;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float block = max(1.0, floor(screen_size.y / target_height));
	vec2 cell = floor(SCREEN_UV * screen_size / block);
	vec2 sample_uv = (cell + vec2(0.5)) * block / screen_size;
	sample_uv = clamp(sample_uv, SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
	COLOR = vec4(textureLod(scene_texture, sample_uv, 0.0).rgb, 1.0);
}
