// Portal surface: shows what the portal camera rendered, sampled in screen space.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled, depth_draw_opaque;

#include "res://shaders/portal_common.gdshaderinc"

uniform sampler2D tex_main : filter_linear, repeat_disable;
uniform sampler2D tex_l2 : filter_linear, repeat_disable;
uniform bool main_active = false;
uniform int l2_parent = -1;
uniform vec3 fallback_color = vec3(0.03, 0.03, 0.035);
uniform float l2_fade_start = 8.0;
uniform float l2_fade_end = 18.0;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (portal_clipped(wp, CAMERA_VISIBLE_LAYERS)) {
		discard;
	}
	uint id = portal_cam_id(CAMERA_VISIBLE_LAYERS);
	vec3 col = fallback_color;
	if (id == 0u) {
		if (main_active) {
			col = texture(tex_main, SCREEN_UV).rgb;
		}
	} else if (int(id) == l2_parent) {
		vec3 c = texture(tex_l2, SCREEN_UV).rgb;
		float f = smoothstep(l2_fade_start, l2_fade_end, length(VERTEX));
		col = mix(c, fallback_color, f);
	}
	ALBEDO = col;
}
