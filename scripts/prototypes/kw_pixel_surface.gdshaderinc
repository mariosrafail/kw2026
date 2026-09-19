// Object-space color cells: attached to each surface, never animated screen grain.
uniform bool pixel_enabled = true;
uniform float pixel_cell_size : hint_range(0.01, 1.0) = 0.07;
uniform float noise_strength : hint_range(0.0, 0.25) = 0.13;
varying vec3 pixel_local_position;

float kw_cell_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
vec3 kw_pixel_color(vec3 color) {
	if (!pixel_enabled) { return color; }
	vec3 grid = pixel_local_position / max(pixel_cell_size, 0.001);
	float fine = kw_cell_hash(floor(grid + 0.001));
	float clusters = kw_cell_hash(floor(grid * 0.5 + 0.001) + vec3(19.0));
	float tone = floor(mix(clusters, fine, 0.38) * 5.0) * 0.25 - 0.5;
	// Fade details that are too small to resolve, rather than letting them shimmer.
	vec3 footprint = fwidth(grid);
	float visible = 1.0 - smoothstep(0.7, 2.2, max(max(footprint.x, footprint.y), footprint.z));
	return color * (1.0 + tone * 2.0 * noise_strength * visible);
}
