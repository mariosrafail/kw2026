shader_type canvas_item;

uniform float speed = 1.0;
uniform float saturation = 1.0;
uniform float value = 1.0;
uniform float shadow = 0.18;

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a * COLOR.a;
	if (a <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		float hue = fract(TIME * speed);
		vec3 rgb = hsv2rgb(vec3(hue, saturation, value));
		float g = clamp(dot(tex.rgb, vec3(0.333333)), 0.0, 1.0);
		float shade = mix(shadow, 1.0, g);
		vec3 shaded = rgb * shade * g;
		COLOR = vec4(shaded, 1.0);
		COLOR.a = a;
	}
}
