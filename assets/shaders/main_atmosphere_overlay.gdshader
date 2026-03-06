shader_type canvas_item;

uniform float time_sec = 0.0;
uniform vec4 glow_a : source_color = vec4(0.07, 0.64, 0.92, 0.18);
uniform vec4 glow_b : source_color = vec4(0.96, 0.62, 0.15, 0.12);
uniform float grain_amount : hint_range(0.0, 0.2) = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec2 drift_uv = uv + vec2(time_sec * 0.01, -time_sec * 0.006);
	float sweep = smoothstep(0.0, 0.7, uv.y) * (0.45 + 0.55 * sin(uv.x * 7.5 + time_sec * 0.7));
	float diagonal = smoothstep(0.2, 0.95, 1.0 - abs(uv.x - uv.y * 0.75));
	float grain = (hash(floor(drift_uv * vec2(320.0, 180.0))) - 0.5) * grain_amount;
	vec3 color = mix(glow_a.rgb, glow_b.rgb, uv.y * 0.75 + 0.15 * sin(time_sec * 0.35));
	float alpha = glow_a.a * sweep + glow_b.a * diagonal;
	alpha += grain;
	alpha *= 0.7 + 0.3 * smoothstep(0.0, 0.6, sin(time_sec * 0.45) * 0.5 + 0.5);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.28));
}
