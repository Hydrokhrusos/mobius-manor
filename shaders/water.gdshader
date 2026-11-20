shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

#include "res://shaders/portal_common.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.04, 0.16, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.38, 0.4, 1.0);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (portal_clipped(v_world, CAMERA_VISIBLE_LAYERS)) {
		discard;
	}
	vec2 p = v_world.xz;
	float t = TIME;
	float w1 = sin(p.x * 4.0 + t * 1.3) * cos(p.y * 3.0 - t * 1.1);
	float w2 = sin((p.x + p.y) * 6.0 - t * 2.0);
	vec3 n = normalize(vec3(w1 * 0.08 + w2 * 0.04, 1.0, w2 * 0.06 - w1 * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.35 + 0.2 * w1);
	ROUGHNESS = 0.06;
	METALLIC = 0.1;
	SPECULAR = 0.9;
	EMISSION = vec3(0.03, 0.08, 0.09) * fres;
}
