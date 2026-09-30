shader_type spatial;
// Stylised lagoon water (works on the Compatibility renderer).
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.04, 0.27, 0.36);
uniform vec3 shallow : source_color = vec3(0.13, 0.50, 0.56);
uniform vec3 glint : source_color = vec3(0.90, 0.96, 0.98);

varying vec3 wpos;

float wave(vec2 p, float t) {
	return sin(p.x * 0.35 + t * 1.3) * 0.5
		+ sin(p.y * 0.27 - t * 0.9) * 0.5
		+ sin((p.x + p.y) * 0.8 + t * 2.1) * 0.25;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	float w = wave(wpos.xz, t);
	vec2 e = vec2(0.4, 0.0);
	float dx = wave(wpos.xz + e.xy, t) - wave(wpos.xz - e.xy, t);
	float dz = wave(wpos.xz + e.yx, t) - wave(wpos.xz - e.yx, t);
	vec3 n = normalize(vec3(-dx * 0.3, 1.0, -dz * 0.3));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float g = smoothstep(0.95, 1.2, w);
	ALBEDO = mix(deep, shallow, 0.45 + 0.2 * w) + glint * g * 0.18;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
}
