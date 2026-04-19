shader_type canvas_item;

uniform float inflate_amount : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec = 0.0;
uniform vec4 accent_color : source_color = vec4(0.33, 0.93, 1.0, 1.0);

void vertex() {
	float mid_x = abs(UV.x - 0.5) * 2.0;
	float belly_band = smoothstep(0.18, 0.42, UV.y) * (1.0 - smoothstep(0.72, 0.98, UV.y));
	float center_weight = 1.0 - pow(mid_x, 1.7);
	float swell = inflate_amount * belly_band * center_weight;
	VERTEX.x += (UV.x - 0.5) * swell * 18.0;
	VERTEX.y -= swell * 5.5;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float mid_x = abs(UV.x - 0.5) * 2.0;
	float belly_band = smoothstep(0.16, 0.4, UV.y) * (1.0 - smoothstep(0.76, 1.0, UV.y));
	float center_weight = 1.0 - pow(mid_x, 1.4);
	float highlight = inflate_amount * belly_band * center_weight;
	float shimmer = 0.82 + 0.18 * sin(time_sec * 7.0 + UV.y * 8.0);
	vec3 glossy = mix(tex.rgb, accent_color.rgb, highlight * 0.24);
	glossy += accent_color.rgb * highlight * 0.08 * shimmer;
	COLOR = vec4(glossy, tex.a);
}
