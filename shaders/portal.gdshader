// Portal surface: shows what a portal camera rendered, sampled in screen space.
// A portal can be seen by several cameras in one frame (the main camera and other portal
// cameras). Each camera that sees it gets its own view texture; view_parent holds the id
// of the camera each texture belongs to (0 = main camera, -1 = unused).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled, depth_draw_opaque;

#include "res://shaders/portal_common.gdshaderinc"

uniform sampler2D view0 : filter_linear, repeat_disable;
uniform sampler2D view1 : filter_linear, repeat_disable;
uniform sampler2D view2 : filter_linear, repeat_disable;
uniform sampler2D view3 : filter_linear, repeat_disable;
uniform ivec4 view_parent = ivec4(-1);
uniform vec3 fallback_color = vec3(0.03, 0.03, 0.035);
// Fades to the fallback colour with distance. Applied the same way at every recursion
// level, so a portal looks identical whether it is seen directly or through another
// portal, and walking through a portal never changes what you see.
uniform float fade_start = 40.0;
uniform float fade_end = 60.0;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (portal_clipped(wp, CAMERA_VISIBLE_LAYERS)) {
		discard;
	}
	int id = int(portal_cam_id(CAMERA_VISIBLE_LAYERS));
	vec3 col = fallback_color;
	bool found = true;
	if (id == view_parent.x) {
		col = texture(view0, SCREEN_UV).rgb;
	} else if (id == view_parent.y) {
		col = texture(view1, SCREEN_UV).rgb;
	} else if (id == view_parent.z) {
		col = texture(view2, SCREEN_UV).rgb;
	} else if (id == view_parent.w) {
		col = texture(view3, SCREEN_UV).rgb;
	} else {
		found = false;
	}
	if (found) {
		col = mix(col, fallback_color, smoothstep(fade_start, fade_end, length(VERTEX)));
	}
	ALBEDO = col;
}
