shader_type spatial;
render_mode specular_disabled, ambient_light_disabled, shadows_disabled;

#include "res://scripts/prototypes/kw_pixel_surface.gdshaderinc"

uniform float flash_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	pixel_local_position = VERTEX;
}

void fragment() {
	vec3 color = COLOR.rgb;
	color = kw_pixel_color(color);
	color = mix(color, vec3(1.0), flash_strength);
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = smoothstep(0.68, 0.94, 1.0 - max(dot(NORMAL, VIEW), 0.0));
	EMISSION = color * (0.62 + rim * 0.055);
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float band = 0.14 + 0.38 * smoothstep(0.20, 0.25, ndl);
	band += 0.46 * smoothstep(0.64, 0.70, ndl);
	vec3 key = min(LIGHT_COLOR / PI, vec3(1.20));
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, key * band * ATTENUATION * 0.60);
}
