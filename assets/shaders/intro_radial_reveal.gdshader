shader_type canvas_item;

uniform float reveal_radius : hint_range(0.0, 1.6) = 0.0;
uniform float feather : hint_range(0.0, 0.3) = 0.015;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform vec4 overlay_tint : source_color = vec4(0.6039, 0.4118, 0.8824, 1.0);

void fragment() {
	float d = distance(UV, center_uv);
	float a = 1.0;
	if (reveal_radius > 0.001) {
		a = smoothstep(reveal_radius, reveal_radius + feather, d);
	}
	COLOR = vec4(overlay_tint.rgb, a * overlay_tint.a);
}
