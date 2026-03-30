shader_type canvas_item;
render_mode blend_mix;

uniform float shimmer_speed : hint_range(0.05, 2.0) = 0.34;
uniform float shimmer_width : hint_range(0.05, 0.5) = 0.28;
uniform float shimmer_softness : hint_range(0.01, 0.4) = 0.16;
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.26;
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.16;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float sweep = fract(UV.x * 0.82 + UV.y * 0.58 - TIME * shimmer_speed);
	float band_dist = abs(sweep - 0.5);
	float band = 1.0 - smoothstep(shimmer_width, shimmer_width + shimmer_softness, band_dist);
	float sparkle = 0.8 + 0.2 * sin((UV.x * 23.0 + UV.y * 31.0) + TIME * 2.1);
	float glow = band * sparkle * shimmer_strength * base.a;
	vec3 tinted = mix(base.rgb, tint_color.rgb, tint_mix);
	vec3 rgb = tinted + shimmer_color.rgb * glow;
	COLOR = vec4(rgb, base.a);
}
