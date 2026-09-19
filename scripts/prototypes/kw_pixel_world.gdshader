shader_type spatial;
render_mode specular_disabled;
#include "res://scripts/prototypes/kw_pixel_surface.gdshaderinc"
uniform bool comic_enabled = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool use_texture = false;
uniform vec4 glow_color : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float glow_energy = 0.0;
void vertex() { pixel_local_position = VERTEX; }
void fragment() {
	vec3 color = base_color.rgb;
	if (use_texture) color *= texture(albedo_texture,UV).rgb;
	color = kw_pixel_color(color);
	ALBEDO = color * (glow_energy>0.0 ? 0.48 : 1.0);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = kw_pixel_color(glow_color.rgb)*glow_energy;
	if (comic_enabled) EMISSION += color*0.13;
}
void light() {
	float ndl = max(dot(NORMAL,LIGHT),0.0);
	if (comic_enabled) {
		float band = 0.13 + 0.39*smoothstep(0.22,0.245,ndl);
		band += 0.48*smoothstep(0.64,0.67,ndl);
		vec3 key = min(LIGHT_COLOR/PI,vec3(1.25));
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, key*band*ATTENUATION*0.8);
	} else {
		DIFFUSE_LIGHT += ndl*LIGHT_COLOR*ATTENUATION/PI;
	}
}
