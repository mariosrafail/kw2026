shader_type spatial;
render_mode specular_disabled, ambient_light_disabled, shadows_disabled;

#include "res://scripts/prototypes/kw_pixel_surface.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.56, 0.114, 0.153, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool use_texture = false;
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.65;
uniform float rim_strength : hint_range(0.0, 0.3) = 0.045;

void vertex() {
	pixel_local_position = VERTEX;
}

void fragment() {
	vec3 color = base_color.rgb;
	if (use_texture) { color *= texture(albedo_texture, UV).rgb; }
	color = kw_pixel_color(color);
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = smoothstep(0.65, 0.92, 1.0 - max(dot(NORMAL, VIEW), 0.0));
	EMISSION = color * (shadow_fill + rim * rim_strength);
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float band = 0.12 + 0.40 * smoothstep(0.20, 0.24, ndl);
	band += 0.48 * smoothstep(0.65, 0.69, ndl);
	vec3 key = min(LIGHT_COLOR / PI, vec3(1.20));
	// The strongest local light wins; neon lights cannot wash the red to white.
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, key * band * ATTENUATION * 0.60);
}
