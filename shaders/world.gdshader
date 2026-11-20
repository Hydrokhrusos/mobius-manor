// Procedural triplanar surface shader used for every solid object in the house.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/portal_common.gdshaderinc"

// 0 plain, 1 checker, 2 planks, 3 stripes, 4 tiles, 5 bricks, 6 blotchy,
// 7 dots, 8 horizontal bands, 9 beach-ball segments (object space)
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool object_space = false;
uniform float grime = 0.1;

varying vec3 v_world;
varying vec3 v_ppos;
varying vec3 v_pnrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

vec3 pat(vec2 uv) {
	float s = max(pattern_scale, 0.001);
	vec3 a = albedo.rgb;
	vec3 b = albedo2.rgb;
	if (pattern == 1) {
		vec2 c = floor(uv / s + 0.0001);
		return mix(a, b, mod(c.x + c.y, 2.0));
	} else if (pattern == 2) {
		float w = 0.2 * s;
		float len = 1.8 * s;
		float row = floor(uv.y / w);
		float off = hash12(vec2(row, 7.3)) * len;
		float u = uv.x + off;
		float col = floor(u / len);
		float id = hash12(vec2(row, col));
		float fx = fract(u / len) * len;
		float fy = fract(uv.y / w) * w;
		vec3 base = mix(a, b, id);
		float grain = vnoise(vec2(u * 2.0, (uv.y / s) * 34.0 + id * 13.0));
		base *= 0.84 + 0.28 * grain;
		float seam = max(1.0 - smoothstep(0.0, 0.007, fy), 1.0 - smoothstep(0.0, 0.009, fx));
		return mix(base, base * 0.35, seam);
	} else if (pattern == 3) {
		float x = fract(uv.x / s);
		vec3 c = x < 0.5 ? a : b;
		float edge = min(abs(x - 0.5), min(x, 1.0 - x));
		return mix(c * 0.8, c, smoothstep(0.0, 0.02, edge));
	} else if (pattern == 4) {
		vec2 f = fract(uv / s);
		vec2 c = floor(uv / s);
		float g = 0.035;
		float grout = 1.0 - smoothstep(0.0, g, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		vec3 base = a * (0.88 + 0.24 * hash12(c));
		return mix(base, b, grout);
	} else if (pattern == 5) {
		vec2 bs = vec2(0.5, 0.25) * s;
		float row = floor(uv.y / bs.y);
		float u = uv.x + mod(row, 2.0) * bs.x * 0.5;
		vec2 c = vec2(floor(u / bs.x), row);
		vec2 f = vec2(fract(u / bs.x) * bs.x, fract(uv.y / bs.y) * bs.y);
		float m = 0.018 * s;
		float mortar = (f.x < m || f.y < m) ? 1.0 : 0.0;
		vec3 base = a * (0.72 + 0.45 * hash12(c));
		return mix(base, b, mortar);
	} else if (pattern == 6) {
		float n = fbm(uv / s);
		return mix(a, b, smoothstep(0.3, 0.72, n));
	} else if (pattern == 7) {
		vec2 f = fract(uv / s) - 0.5;
		float d = length(f);
		return mix(b, a, smoothstep(0.17, 0.2, d));
	} else if (pattern == 8) {
		float y = fract(uv.y / s);
		return y < 0.5 ? a : b;
	}
	return a;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (object_space) {
		v_ppos = VERTEX;
		v_pnrm = NORMAL;
	} else {
		v_ppos = v_world;
		v_pnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	if (portal_clipped(v_world, CAMERA_VISIBLE_LAYERS)) {
		discard;
	}
	vec3 n = normalize(v_pnrm);
	vec3 col;
	if (pattern == 9) {
		float ang = atan(v_ppos.z, v_ppos.x);
		float seg = floor((ang + 3.14159265) / (6.2831853 / 6.0));
		col = mod(seg, 2.0) < 1.0 ? albedo.rgb : albedo2.rgb;
		if (abs(normalize(v_ppos).y) > 0.93) {
			col = vec3(0.95);
		}
	} else if (pattern == 0) {
		col = albedo.rgb;
	} else {
		vec3 w = pow(abs(n), vec3(8.0));
		w /= (w.x + w.y + w.z + 1e-5);
		col = vec3(0.0);
		if (w.x > 0.02) { col += w.x * pat(v_ppos.zy); }
		if (w.y > 0.02) { col += w.y * pat(v_ppos.xz); }
		if (w.z > 0.02) { col += w.z * pat(v_ppos.xy); }
	}
	if (grime > 0.0) {
		vec2 guv = abs(n.y) > 0.5 ? v_ppos.xz : (abs(n.x) > 0.5 ? v_ppos.zy : v_ppos.xy);
		float g = fbm(guv * 1.7);
		col *= 1.0 - grime + grime * 2.0 * g;
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = emission.rgb * emission_energy;
}
