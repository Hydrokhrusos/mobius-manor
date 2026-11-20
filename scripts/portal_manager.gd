class_name PortalManager
extends Node
## Renders portals through a small pool of SubViewports (level-1 views seen directly by
## the player, plus a few level-2 views seen through another portal), teleports the
## player and physics props, and offers raycasts that pass through portals.

const MAX_SLOTS := 6
const MAX_L1 := 4
const MAX_DIST := 75.0

class Slot:
	var vp: SubViewport
	var cam: Camera3D
	var id := 0
	var portal = null
	var active := false

var portals: Array = []
var slots: Array = []
var main_cam: Camera3D
var env: Environment
var clip_img: Image
var clip_tex: ImageTexture
var quality := 1.0
var _size := Vector2i.ZERO
var _prev_pos := {}
var _over_is_outside := true
var _frustum_checked := false
var stats_active := 0


func setup(p_portals: Array, cam: Camera3D, portal_env: Environment) -> void:
	portals = p_portals
	main_cam = cam
	env = portal_env
	process_priority = 100
	process_physics_priority = 100
	clip_img = Image.create(64, 1, false, Image.FORMAT_RGBAF)
	clip_img.fill(Color(0.0, 0.0, 0.0, -1.0))
	clip_tex = ImageTexture.create_from_image(clip_img)
	RenderingServer.global_shader_parameter_set("portal_clip_planes", clip_tex)
	for i in MAX_SLOTS:
		var s := Slot.new()
		s.id = i + 1
		s.vp = SubViewport.new()
		s.vp.name = "PortalView%d" % s.id
		s.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		s.vp.use_hdr_2d = true
		s.vp.msaa_3d = Viewport.MSAA_2X
		s.vp.positional_shadow_atlas_size = 2048
		s.vp.audio_listener_enable_3d = false
		s.vp.gui_disable_input = true
		s.vp.size = Vector2i(64, 64)
		add_child(s.vp)
		s.cam = Camera3D.new()
		s.cam.environment = env
		s.vp.add_child(s.cam)
		s.cam.current = true
		slots.append(s)
	for p in portals:
		p.refresh_xf()


func set_quality(q: float) -> void:
	quality = q
	_size = Vector2i.ZERO


func _process(_delta: float) -> void:
	if main_cam == null:
		return
	var vsz := Vector2i((get_viewport().get_visible_rect().size * quality).round())
	vsz = vsz.max(Vector2i(64, 64))
	if vsz != _size:
		_size = vsz
		for s in slots:
			s.vp.size = vsz
	var cam_t := main_cam.global_transform
	var cam_pos := cam_t.origin
	var frustum := main_cam.get_frustum()
	if not _frustum_checked:
		_frustum_checked = true
		var probe := cam_pos - cam_t.basis.z * 5.0
		var overs := 0
		for pl in frustum:
			if pl.is_point_over(probe):
				overs += 1
		_over_is_outside = overs < 3

	for p in portals:
		p.l2_assigned = false
		p.near_update(cam_pos)
		if p.mat:
			p.mat.set_shader_parameter("main_active", false)
			p.mat.set_shader_parameter("l2_parent", -1)

	var cands := []
	for p in portals:
		if not p.can_render or p.target == null:
			continue
		var sc := _score(p, cam_pos, frustum, true)
		if sc > 0.0:
			cands.append([sc, p])
	cands.sort_custom(func(a, b): return a[0] > b[0])

	var used := 0
	var l1 := []
	for c in cands:
		if used >= MAX_L1:
			break
		var p = c[1]
		var s: Slot = slots[used]
		used += 1
		_activate(s, p, p.link() * cam_t)
		p.mat.set_shader_parameter("tex_main", s.vp.get_texture())
		p.mat.set_shader_parameter("main_active", true)
		l1.append(s)

	for ps in l1:
		if used >= MAX_SLOTS:
			break
		var parent = ps.portal
		var exit = parent.target
		var vt: Transform3D = ps.cam.global_transform
		var vfr: Array = ps.cam.get_frustum()
		var prect := _screen_rect(main_cam, parent)
		if prect.size.x <= 0.0 or prect.size.y <= 0.0:
			continue
		var best = null
		var best_sc := 0.0
		for q in portals:
			if q == exit or q.l2_assigned or not q.can_render or q.target == null or q.no_l2:
				continue
			if exit.signed_dist(q.center()) < 0.02:
				continue
			var sc := _score(q, vt.origin, vfr, false)
			if sc <= best_sc:
				continue
			var qrect := _screen_rect(ps.cam, q)
			if not prect.intersects(qrect):
				continue
			best = q
			best_sc = sc
		if best != null:
			var s: Slot = slots[used]
			used += 1
			_activate(s, best, best.link() * vt)
			best.l2_assigned = true
			best.mat.set_shader_parameter("tex_l2", s.vp.get_texture())
			best.mat.set_shader_parameter("l2_parent", ps.id)

	stats_active = used
	_update_clones()
	for i in range(used, MAX_SLOTS):
		var s: Slot = slots[i]
		if s.active:
			s.active = false
			s.portal = null
			s.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			clip_img.set_pixel(s.id, 0, Color(0.0, 0.0, 0.0, -1.0))
	clip_tex.update(clip_img)


func _activate(s: Slot, p, xform: Transform3D) -> void:
	s.portal = p
	s.active = true
	s.cam.global_transform = xform.orthonormalized()
	s.cam.fov = main_cam.fov
	s.cam.near = main_cam.near
	s.cam.far = main_cam.far
	s.cam.cull_mask = p.cam_layers | (s.id << 8)
	s.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ex = p.target
	var n: Vector3 = ex.normal()
	clip_img.set_pixel(s.id, 0, Color(n.x, n.y, n.z, n.dot(ex.center()) + 0.002))


func _outside(pl: Plane, pt: Vector3) -> bool:
	return pl.is_point_over(pt) == _over_is_outside


func _score(p, cam_pos: Vector3, frustum: Array, occl: bool) -> float:
	var sd: float = p.signed_dist(cam_pos)
	if sd < -0.02:
		return 0.0
	var cs: Array = p.corners(1.0)
	for pl in frustum:
		var all_out := true
		for c in cs:
			if not _outside(pl, c):
				all_out = false
				break
		if all_out:
			return 0.0
	var lp: Vector3 = p.to_local_p(cam_pos)
	var cl := Vector3(clampf(lp.x, -p.size.x * 0.5, p.size.x * 0.5), clampf(lp.y, -p.size.y * 0.5, p.size.y * 0.5), 0.0)
	var dist := lp.distance_to(cl)
	if dist > MAX_DIST:
		return 0.0
	if occl and dist > 0.7 and not _ray_visible(cam_pos, p):
		return 0.0
	return p.size.x * p.size.y / maxf(dist * dist, 0.05)


func _ray_visible(from: Vector3, p) -> bool:
	var space := main_cam.get_world_3d().direct_space_state
	var pts: Array = [p.center()]
	pts.append_array(p.corners(0.8))
	pts.append_array(p.corners(0.4))
	for t in pts:
		var q := PhysicsRayQueryParameters3D.create(from, t, G.PL_WORLD)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(t) < 0.05:
			return true
	return false


func _screen_rect(cam: Camera3D, p) -> Rect2:
	var full := Rect2(0.0, 0.0, 1.0, 1.0)
	var vs := cam.get_viewport().get_visible_rect().size
	var r := Rect2()
	var first := true
	for c in p.corners(1.0):
		if cam.is_position_behind(c):
			return full
		var sp: Vector2 = cam.unproject_position(c) / vs
		if first:
			r = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			r = r.expand(sp)
	return r.intersection(full)


# --- Visual clones of props that are half-way through a portal ---------------------

var _clones := {}


func _body_radius(rb: RigidBody3D) -> float:
	if rb.has_meta("portal_r"):
		return rb.get_meta("portal_r")
	var r := 0.2
	for c in rb.get_children():
		if c is MeshInstance3D and c.mesh:
			var bb: AABB = (c.transform * c.mesh.get_aabb())
			r = maxf(r, maxf(bb.position.abs().length(), bb.end.abs().length()))
	rb.set_meta("portal_r", r)
	return r


func _update_clones() -> void:
	var used := {}
	for b in get_tree().get_nodes_in_group("travelers"):
		var rb := b as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var bid := rb.get_instance_id()
		if rb.sleeping:
			# keep whatever clone a resting body already has
			for k in _clones.keys():
				if (k as String).begins_with("%d_" % bid):
					used[k] = true
			continue
		var pos := rb.global_position
		var r := _body_radius(rb)
		for i in portals.size():
			var p = portals[i]
			if not p.can_teleport or p.target == null:
				continue
			var sd: float = p.signed_dist(pos)
			if sd < 0.0 or sd > r:
				continue
			var lp: Vector3 = p.to_local_p(pos)
			if absf(lp.x) > p.size.x * 0.5 + r or absf(lp.y) > p.size.y * 0.5 + r:
				continue
			var key := "%d_%d" % [bid, i]
			var c: Node3D = _clones.get(key)
			if c == null:
				c = _make_clone(rb)
				_clones[key] = c
			c.global_transform = p.link() * rb.global_transform
			used[key] = true
			break
	for k in _clones.keys():
		if not used.has(k):
			var c = _clones[k]
			if is_instance_valid(c):
				c.queue_free()
			_clones.erase(k)


func _make_clone(rb: RigidBody3D) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	for c in rb.get_children():
		if c is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = c.mesh
			m.material_override = c.material_override
			m.transform = c.transform
			m.layers = c.layers
			n.add_child(m)
	return n


# --- Teleporting -----------------------------------------------------------------

func check_player_cross(prev_eye: Vector3, eye: Vector3) -> void:
	for p in portals:
		if p.can_teleport and p.target != null and p.crossed(prev_eye, eye):
			var L: Transform3D = p.link()
			G.player.portal_teleport(L, p, p.target)
			if p.on_teleport.is_valid():
				p.on_teleport.call(G.player)
			return


func _physics_process(_delta: float) -> void:
	var next := {}
	for b in get_tree().get_nodes_in_group("travelers"):
		var rb := b as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var id := rb.get_instance_id()
		var pos := rb.global_position
		if _prev_pos.has(id):
			var prev: Vector3 = _prev_pos[id]
			for p in portals:
				if p.can_teleport and p.target != null and p.crossed(prev, pos):
					teleport_body(rb, p)
					pos = rb.global_position
					break
		next[id] = pos
	_prev_pos = next


func teleport_body(rb: RigidBody3D, p) -> void:
	var L: Transform3D = p.link()
	rb.global_transform = L * rb.global_transform
	rb.linear_velocity = L.basis * rb.linear_velocity
	rb.angular_velocity = L.basis * rb.angular_velocity
	if G.player and G.player.held == rb:
		G.player.held_link = L * G.player.held_link
	if p.on_teleport.is_valid():
		p.on_teleport.call(rb)
	if G.world:
		G.world.update_body_layers(rb)


# --- Raycasts through portals ---------------------------------------------------------

func portal_raycast(from: Vector3, dir: Vector3, max_len: float, mask: int, exclude: Array) -> Dictionary:
	var space := main_cam.get_world_3d().direct_space_state
	var o := from
	var d := dir.normalized()
	var remaining := max_len
	var link := Transform3D.IDENTITY
	var travelled := 0.0
	for i in 4:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * remaining, mask, exclude)
		var hit := space.intersect_ray(q)
		var hit_t := remaining
		if not hit.is_empty():
			hit_t = o.distance_to(hit.position)
		var bp = null
		var bt := hit_t
		for p in portals:
			if not p.can_teleport or p.target == null:
				continue
			var t: float = p.ray_hit(o, d, bt)
			if t >= 0.0 and t < bt:
				bt = t
				bp = p
		if bp != null:
			var L: Transform3D = bp.link()
			o = L * (o + d * bt)
			d = (L.basis * d).normalized()
			remaining -= bt
			travelled += bt
			link = L * link
			o += d * 0.002
			continue
		return {
			"hit": not hit.is_empty(),
			"collider": hit.get("collider"),
			"position": hit.get("position", o + d * remaining),
			"normal": hit.get("normal", Vector3.ZERO),
			"dir": d,
			"link": link,
			"distance": travelled + hit_t,
		}
	return {"hit": false, "collider": null, "position": o, "normal": Vector3.ZERO, "dir": d, "link": link, "distance": max_len}
