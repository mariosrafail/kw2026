shader_type canvas_item;

void fragment() {
	vec2 p=UV-vec2(0.5);
	float aspect=SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x;
	p.x*=aspect;
	float r=length(p);
	float outside=smoothstep(0.485,0.505,r);
	float ring=1.0-smoothstep(0.006,0.013,abs(r-0.475));
	float cross_h=(1.0-smoothstep(0.0015,0.004,abs(p.y)))*step(abs(p.x),0.33);
	float cross_v=(1.0-smoothstep(0.0015,0.004,abs(p.x)))*step(abs(p.y),0.33);
	float center=1.0-smoothstep(0.002,0.008,r);
	vec3 reticle=vec3(0.92,0.96,1.0);
	vec3 color=mix(reticle,vec3(0.005,0.006,0.009),outside);
	float alpha=max(outside*0.985,max(ring*0.88,max(cross_h,cross_v)*0.72));
	alpha=max(alpha,center);
	COLOR=vec4(color,alpha);
}