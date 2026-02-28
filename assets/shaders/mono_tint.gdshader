shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shadow = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a * COLOR.a * tint_color.a;
	if (a <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		float g = clamp(dot(tex.rgb, vec3(0.333333)), 0.0, 1.0);
		float shade = mix(shadow, 1.0, g);
		vec3 shaded = tint_color.rgb * shade * g;
		COLOR = vec4(shaded, 1.0);
		COLOR.a = a;
	}
}
