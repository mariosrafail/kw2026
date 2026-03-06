shader_type canvas_item;

uniform vec4 edge_color : source_color = vec4(0.02, 0.03, 0.08, 0.72);
uniform vec4 center_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float pulse_sec = 0.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered * vec2(1.0, 0.78));
	float vignette = smoothstep(0.42, 1.08, radius);
	float pulse = 0.96 + 0.04 * sin(pulse_sec * 0.55);
	vec4 tint = mix(center_tint, edge_color, vignette * pulse);
	COLOR = tint;
}
