// Shared portal clipping logic.
// Every portal camera encodes its slot id in cull-mask bits 8..19. The clip plane for
// that slot lives in a 64x1 float texture: xyz = plane normal, w = plane distance.
// Fragments behind the exit portal's plane are discarded, which acts like an oblique
// near plane so geometry between the virtual camera and the exit portal never occludes.

global uniform sampler2D portal_clip_planes;

uint portal_cam_id(uint layers) {
	return (layers >> 8u) & 4095u;
}

bool portal_clipped(vec3 wp, uint layers) {
	uint id = portal_cam_id(layers);
	if (id == 0u || id >= 64u) {
		return false;
	}
	vec4 pl = texelFetch(portal_clip_planes, ivec2(int(id), 0), 0);
	return dot(pl.xyz, wp) < pl.w;
}
