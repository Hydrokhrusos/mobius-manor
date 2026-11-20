shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

#include "res://shaders/portal_common.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.85, 0.95, 1.0, 0.07);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (portal_clipped(v_world, CAMERA_VISIBLE_LAYERS)) {
		discard;
	}
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(tint.a + f * 0.45, 0.0, 0.85);
	ROUGHNESS = 0.04;
	SPECULAR = 0.8;
}
